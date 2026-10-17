module Accounts
  class ApiTokensController < ApplicationController
    before_action :private_response
    before_action :set_token, only: %i[show destroy rotate]

    rescue_from ActiveRecord::RecordNotFound, with: -> { token_error("not_found", :not_found) }
    rescue_from ActionController::ParameterMissing, with: -> { token_error("invalid_request", :bad_request) }
    rescue_from ActiveRecord::RecordInvalid, with: -> { token_error("validation_failed", :unprocessable_content) }

    def index
      render json: {api_tokens: owned_tokens.order(:id).map(&:public_metadata)}
    end

    def show
      render json: {api_token: @token.public_metadata}
    end

    def create
      token = ApiToken.transaction { issue_token! }
      render json: {api_token: token.public_metadata, secret: token.token}, status: :created
    end

    def destroy
      @token.with_lock do
        unless @token.revoked_at
          @token.update!(revoked_at: Time.current)
          audit!(@token, "revoked")
        end
      end
      render json: {api_token: @token.public_metadata}
    end

    def rotate
      replacement = @token.with_lock do
        raise ActiveRecord::RecordNotFound if @token.revoked_at
        issued = issue_token!
        @token.update!(revoked_at: Time.current)
        audit!(@token, "rotated")
        issued
      end
      render json: {api_token: replacement.public_metadata, secret: replacement.token}, status: :created
    end

    def claim
      digest = ApiToken.digest(params.require(:token))
      token = Current.account.api_tokens.where(user_id: nil).find_by!(token_digest: digest)
      token.with_lock do
        raise ActiveRecord::RecordNotFound if token.user_id
        token.update!(user: Current.user)
        audit!(token, "claimed")
      end
      render json: {api_token: token.public_metadata}
    end

    private

    def owned_tokens
      Current.account.api_tokens.where(user: Current.user)
    end

    def issue_token!
      token = owned_tokens.new(issue_attributes)
      token.save!(context: :issue)
      audit!(token, "issued")
      token
    end

    def audit!(token, action)
      token.audits.create!(account: Current.account, user: Current.user, action: action, request_id: request.request_id)
    end

    def set_token
      @token = owned_tokens.find(params[:id])
    end

    def issue_attributes
      envelope = params.require(:api_token)
      raise ActionController::ParameterMissing, :api_token unless envelope.is_a?(ActionController::Parameters)
      attributes = envelope.permit(:name, :expires_at, :read_only, scopes: []).to_h
      raise ActionController::ParameterMissing, :scopes unless attributes["scopes"].is_a?(Array)
      attributes
    end

    def private_response
      response.headers["Cache-Control"] = "no-store"
      request.set_header("action_dispatch.request_id", SecureRandom.uuid)
    end

    def token_error(code, status)
      render json: {error: {code: code, message: code.humanize}, request_id: request.request_id}, status: status
    end
  end
end
