module Api
  module V1
    class JurisdictionsController < BaseController
      def index
        @jurisdictions = Jurisdiction.all.order(:name)
      end

      def show
        @jurisdiction = Jurisdiction.find_by!(code: params[:id])
        @legislation_count = @jurisdiction.legislations.count
        @type_counts = @jurisdiction.legislations.group(:legislation_type).count
        @status_counts = @jurisdiction.legislations.group(:status).count
      end
    end
  end
end
