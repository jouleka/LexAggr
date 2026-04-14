module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q]
        return render json: { error: "Query parameter 'q' is required" }, status: :bad_request if query.blank?

        results = Legislation.search_full_text(query).includes(:jurisdiction)
        results = results.where(jurisdiction: Jurisdiction.find_by(code: params[:jurisdiction])) if params[:jurisdiction].present?
        results = results.by_type(params[:type]) if params[:type].present?
        results = results.where(status: params[:status]) if params[:status].present?
        results = results.by_year(params[:year].to_i) if params[:year].present?

        paging = pagination_params
        @total = results.count
        @results = results.offset(paging[:offset]).limit(paging[:limit])
        @page = paging[:page]
        @per_page = paging[:per_page]

        # Facets: count results grouped by key dimensions
        # Use reorder to remove pg_search's ORDER BY rank which conflicts with GROUP BY
        unordered = results.reorder(nil)
        @facets = {
          jurisdictions: unordered.joins(:jurisdiction).group("jurisdictions.code").count,
          types: unordered.group(:legislation_type).count,
          statuses: unordered.group(:status).count,
          years: unordered.group(:year).count.sort_by { |k, _| -(k || 0) }.to_h
        }
      end
    end
  end
end
