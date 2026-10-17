module Api
  module V1
    class ApplicationController < ActionController::Base
      include Pagy::Method

      class_attribute :api_scope_rules, default: {}.freeze

      def self.api_scope(scope, only:)
        raise ArgumentError, "Unknown API scope" unless ApiToken::SCOPES.include?(scope)
        self.api_scope_rules = api_scope_rules.merge(Array(only).map { |action| [action.to_s, scope] }.to_h).freeze
      end

      before_action :set_source
      before_action :authenticate
      before_action :authorize_scope

      rescue_from ActiveRecord::RecordNotFound, with: -> { api_error("not_found", :not_found) }

      skip_forgery_protection

      private

      def authenticate
        authenticated = authenticate_with_http_token { |token, _| Current.api_token = ApiToken.authenticate(token) }
        unless authenticated
          response.headers["WWW-Authenticate"] = "Bearer"
          api_error("unauthorized", :unauthorized)
        end
      end

      def authorize_scope
        token = Current.api_token
        scope = api_scope_rules[action_name]
        permitted = token.permits?(scope) && (!token.read_only? || request.get? || request.head?)
        unless permitted
          return api_error("forbidden", :forbidden)
        end
        token.update_columns(last_used_at: Time.current)
      end

      def api_error(code, status)
        render json: {error: {code: code, message: code.humanize}, request_id: response.headers["X-Request-ID"]}, status: status
      end

      def set_source
        Current.source = :api_v1
        request.set_header("action_dispatch.request_id", SecureRandom.uuid)
        response.headers["X-Request-ID"] = request.request_id
      end
    end
  end
end
