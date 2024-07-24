module Accounts
  class GithubAccessTokensController < ApplicationController
    def create
      @github_access_token = current_account.build_github_access_token(github_access_token_params)

      if @github_access_token.save
        redirect_to account_path, notice: "Github account connected successfully."
      else
        render turbo_stream: replace_form, status: :unprocessable_entity
      end
    end

    def destroy
      current_account.github_access_token&.destroy
      redirect_to account_path, notice: "Github account disconnected successfully."
    end

    private

    def github_access_token_params
      params.require(:github_access_token).permit(:token)
    end

    def replace_form
      turbo_stream.replace(
        "github_access_token_form",
        partial: "accounts/github_access_tokens/form",
        locals: {
          github_access_token: @github_access_token || current_account.github_access_token
        }
      )
    end
  end
end
