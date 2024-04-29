module Api
  module V1
    class ApplicationController < ActionController::Base
      include Pagy::Backend

      before_action :authenticate
      before_action :set_paper_trail_whodunnit

      skip_before_action :verify_authenticity_token

      def current_api_token
        Current.api_token
      end

      def current_org
        Current.org
      end

      private

      def authenticate
        authenticate_or_request_with_http_token do |token, options|
          Current.api_token = ApiToken.find_by!(token:)
        end
      rescue ActiveRecord::RecordNotFound
        head :unauthorized
      end

      def user_for_paper_trail
        current_api_token&.to_global_id
      end
    end
  end
end
