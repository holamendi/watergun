module Api
  module V1
    class ApplicationController < ActionController::Base
      include Pagy::Method

      before_action :set_source
      before_action :authenticate

      skip_forgery_protection

      private

      def authenticate
        authenticate_or_request_with_http_token do |token, options|
          Current.api_token = ApiToken.active.find_by!(token:)
        end
      rescue ActiveRecord::RecordNotFound
        head :unauthorized
      end

      def set_source
        Current.source = :api_v1
      end
    end
  end
end
