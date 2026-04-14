class AlertDigestJob < ApplicationJob
  queue_as :default

  def perform
    User.wants_alerts.find_each do |user|
      changes = find_changes_for_user(user)
      next if changes.empty?

      AlertMailer.daily_digest(user, changes).deliver_later
      user.update_column(:last_digest_sent_at, Time.current)
    end
  end

  private

  def find_changes_for_user(user)
    since = user.last_digest_sent_at || 1.day.ago

    watched_legislation_ids = user.watchlists
      .joins(:watchlist_items)
      .where(watchlist_items: { item_type: "specific_legislation" })
      .pluck("watchlist_items.legislation_id")
      .compact

    # Also get legislation matching jurisdiction filters
    filter_items = WatchlistItem.joins(:watchlist)
      .where(watchlists: { user_id: user.id })
      .where(item_type: "jurisdiction_filter")

    filter_conditions = filter_items.map do |item|
      scope = Legislation.where(jurisdiction_id: item.jurisdiction_id)
      scope = scope.where(legislation_type: item.legislation_type) if item.legislation_type.present?
      scope
    end

    # Combine: specific watched + filter matches
    all_ids = watched_legislation_ids.dup
    filter_conditions.each { |scope| all_ids.concat(scope.pluck(:id)) }
    all_ids.uniq!

    return [] if all_ids.empty?

    Legislation.where(id: all_ids)
               .where("legislations.updated_at > ?", since)
               .includes(:jurisdiction)
               .order(:jurisdiction_id, :title)
               .to_a
  end
end
