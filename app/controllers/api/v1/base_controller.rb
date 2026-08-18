module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_token!

      private

      def authenticate_api_token!
        token = request.headers["Authorization"]&.match(/\ABearer ([0-9a-f]{64})\z/)&.captures&.first
        @current_user = User.authenticate_api_token(token)
        render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
      end

      def current_user
        @current_user
      end

      def pagination_params
        page = (params[:page] || 1).to_i.clamp(1, 1_000_000)
        per_page = (params[:per_page] || 25).to_i.clamp(1, 100)
        offset = (page - 1) * per_page
        { offset: offset, limit: per_page, page: page, per_page: per_page }
      end
    end
  end
end
