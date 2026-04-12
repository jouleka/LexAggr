class SearchController < ApplicationController
  def index
    @query = params[:q]
    @results = if @query.present?
      Legislation.search_full_text(@query)
                 .includes(:jurisdiction)
                 .limit(50)
    else
      Legislation.none
    end
  end
end
