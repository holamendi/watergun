module Orgs
  class ApiTokensController < ApplicationController
    def create
      @api_token = current_org.api_tokens.create!
      redirect_to org_settings_path, notice: "API token created"
    end

    def destroy
      @api_token = current_org.api_tokens.find(params[:id])
      @api_token.destroy
      redirect_to org_settings_path, notice: "API token"
    end
  end
end
