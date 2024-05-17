module Orgs
  class SettingsController < ApplicationController
    def show
      @api_tokens = current_org.api_tokens
    end
  end
end
