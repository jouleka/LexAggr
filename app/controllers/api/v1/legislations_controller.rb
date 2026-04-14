module Api
  module V1
    class LegislationsController < BaseController
      def index
        legislations = Legislation.includes(:jurisdiction).order(created_at: :desc)
        legislations = legislations.where(jurisdiction: Jurisdiction.find_by(code: params[:jurisdiction])) if params[:jurisdiction].present?
        legislations = legislations.by_type(params[:type]) if params[:type].present?
        legislations = legislations.by_year(params[:year].to_i) if params[:year].present?
        legislations = legislations.where(status: params[:status]) if params[:status].present?

        paging = pagination_params
        @total = legislations.count
        @legislations = legislations.offset(paging[:offset]).limit(paging[:limit])
        @page = paging[:page]
        @per_page = paging[:per_page]
      end

      def show
        @legislation = Legislation.includes(:jurisdiction, legislation_versions: :content).find(params[:id])
        @versions = @legislation.legislation_versions.order(valid_from: :desc)
        @current_version = @versions.current.first || @versions.first
      end
    end
  end
end
