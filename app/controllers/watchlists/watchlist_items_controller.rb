module Watchlists
  class WatchlistItemsController < ApplicationController
    def destroy
      watchlist = Current.user.watchlists.find(params[:watchlist_id])
      item = watchlist.watchlist_items.find(params[:id])
      item.destroy
      redirect_to watchlist_path(watchlist), notice: "Item removed."
    end
  end
end
