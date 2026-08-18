class WatchlistsController < ApplicationController
  before_action :set_watchlist, only: [ :show, :destroy ]

  def index
    @watchlists = Current.user.watchlists.includes(watchlist_items: [ :legislation, :jurisdiction ])
  end

  def show
    @items = @watchlist.watchlist_items.includes(:legislation, :jurisdiction)
  end

  def destroy
    @watchlist.destroy
    redirect_to watchlists_path, notice: "Watchlist removed."
  end

  def watch
    legislation = Legislation.find(params[:id])
    watchlist = Watchlist.default_for(Current.user)
    watchlist.watchlist_items.find_or_create_by!(
      legislation: legislation,
      item_type: "specific_legislation"
    )
    redirect_back fallback_location: legislation_path(legislation), notice: "Added to watchlist."
  end

  def unwatch
    legislation = Legislation.find(params[:id])
    Current.user.watchlists.each do |watchlist|
      watchlist.watchlist_items.where(legislation: legislation).destroy_all
    end
    redirect_back fallback_location: legislation_path(legislation), notice: "Removed from watchlist."
  end

  private

  def set_watchlist
    @watchlist = Current.user.watchlists.find(params[:id])
  end
end
