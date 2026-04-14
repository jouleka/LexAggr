class AlertMailer < ApplicationMailer
  def daily_digest(user, changes)
    @user = user
    @changes = changes
    @grouped_changes = changes.group_by { |leg| leg.jurisdiction.name }

    mail(
      to: @user.email_address,
      subject: "LexAggr: #{changes.length} legislation updates in your watchlist"
    )
  end
end
