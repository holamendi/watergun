module Accounts
  class SettingsController < ApplicationController
    def show
      @api_tokens = current_account.api_tokens
    end
  end
end
