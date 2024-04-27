module Orgs
  class GithubAccessTokensController < ApplicationController
    def update
      @github_access_token = current_org.github_access_token || current_org.build_github_access_token

      if @github_access_token.update(github_access_token_params)
        redirect_to org_settings_path, notice: "GitHub access token updated"
      else
        render "orgs/settings/show"
      end
    end

    private

    def github_access_token_params
      params.require(:github_access_token).permit(:token)
    end
  end
end
