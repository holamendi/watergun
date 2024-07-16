module Accounts
  class GithubAccessTokensController < ApplicationController
    def create
      @github_access_token = current_account.build_github_access_token(github_access_token_params)

      if @github_access_token.save
        redirect_to account_settings_path, notice: "Github access token created successfully."
      else
        render turbo_stream: turbo_stream.replace(
          "github_access_token_form",
          partial: "accounts/github_access_tokens/form",
          locals: {
            github_access_token: @github_access_token
          }
        )
      end
    end

    def destroy
      current_account.github_access_token&.destroy
      redirect_to account_settings_path, notice: "Github access token deleted successfully."
    end

    private

    def github_access_token_params
      params.require(:github_access_token).permit(:token)
    end
  end
end
