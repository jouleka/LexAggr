module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_token!

      private

      def authenticate_api_token!
        token = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")
        @current_user = User.find_by(api_token: token) if token.present?
        render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
      end

      def current_user
        @current_user
      end

      def pagination_params
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 25).to_i, 100].min
        offset = (page - 1) * per_page
        { offset: offset, limit: per_page, page: page, per_page: per_page }
      end
    end
  end
end
