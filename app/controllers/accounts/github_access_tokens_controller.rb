module Accounts
  class GithubAccessTokensController < ApplicationController
    def create
      @github_access_token = current_account.build_github_access_token(github_access_token_params)

      if @github_access_token.save
        render turbo_stream: [notify("Github account connected"), render_form]
      else
        render turbo_stream: render_form, status: :unprocessable_entity
      end
    end

    def destroy
      current_account.github_access_token&.destroy
      render turbo_stream: [notify("Github account disconnected"), render_form]
    end

    private

    def github_access_token_params
      params.require(:github_access_token).permit(:token)
    end

    def render_form
      turbo_stream.replace(
        "github_settings",
        partial: "accounts/github_access_tokens/settings",
        locals: {github_access_token: @github_access_token || current_account.build_github_access_token}
      )
    end
  end
end
