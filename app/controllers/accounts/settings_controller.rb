module Accounts
  class SettingsController < ApplicationController
    def show
      @api_tokens = current_account.api_tokens
      @github_access_token = current_account.github_access_token || current_account.build_github_access_token
    end
  end
end
