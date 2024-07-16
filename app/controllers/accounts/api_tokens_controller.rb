module Accounts
  class ApiTokensController < ApplicationController
    def create
      @api_token = current_account.api_tokens.create!
      redirect_to account_settings_path, notice: "API token created successfully"
    end

    def destroy
      @api_token = current_account.api_tokens.find(params[:id])
      @api_token.destroy
      redirect_to account_settings_path, notice: "API token deleted successfully"
    end
  end
end
