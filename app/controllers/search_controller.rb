class SearchController < ApplicationController
  allow_unauthenticated_access

  def index
    @query = params[:q]
    @jurisdiction_filter = params[:jurisdiction]
    @type_filter = params[:type]
    @status_filter = params[:status]
    @year_filter = params[:year]

    if @query.present?
      base_results = Legislation.search_full_text(@query).includes(:jurisdiction)
    else
      base_results = Legislation.includes(:jurisdiction).order(updated_at: :desc)
    end

    # Apply filters
    base_results = base_results.where(jurisdiction: Jurisdiction.find_by(code: @jurisdiction_filter)) if @jurisdiction_filter.present?
    base_results = base_results.by_type(@type_filter) if @type_filter.present?
    base_results = base_results.where(status: @status_filter) if @status_filter.present?
    base_results = base_results.by_year(@year_filter.to_i) if @year_filter.present?

    # Facet counts (on filtered results, excluding the dimension being counted)
    # Use reorder(nil) to strip pg_search rank ordering which conflicts with GROUP BY
    all_matching = @query.present? ? Legislation.search_full_text(@query).reorder(nil) : Legislation.all
    @facets = {
      jurisdictions: all_matching.joins(:jurisdiction).group("jurisdictions.code", "jurisdictions.name").count.transform_keys { |k| { code: k[0], name: k[1] } },
      types: all_matching.group(:legislation_type).count.reject { |k, _| k.nil? },
      statuses: all_matching.group(:status).count.reject { |k, _| k.nil? },
      years: all_matching.group(:year).count.reject { |k, _| k.nil? }.sort_by { |k, _| -(k || 0) }.first(10).to_h
    }

    @results = base_results.limit(50)
    @total = base_results.count
  end
end
