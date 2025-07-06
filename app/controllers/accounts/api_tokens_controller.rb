module Accounts
  class ApiTokensController < ApplicationController
    def index
    end

    def create
      @api_token = Current.account.api_tokens.create(api_token_params)

      if @api_token.save
        redirect_to account_settings_path, notice: "API token created"
        cookies[:api_token] = @api_token.token
      else
        render turbo_stream: turbo_stream.replace(
          "api_token_form",
          partial: "accounts/api_tokens/form",
          locals: {
            api_token: @api_token
          }
        )
      end
    end

    def destroy
      @api_token = Current.account.api_tokens.find(params[:id])
      @api_token.destroy
      redirect_to account_settings_path, notice: "API token deleted successfully"
    end

    private

    def api_token_params
      params.require(:api_token).permit(:name)
    end
  end
end
