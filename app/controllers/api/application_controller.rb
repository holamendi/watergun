module Api
  module V1
    class ApplicationController < ApplicationController
      before_action :authenticate

      private

      def authenticate
        authenticate_or_request_with_http_token do |token, options|
          Current.api_token =
        end
      end

      attr_reader :current_user
    end
  end
end
