module Orgs
  class SettingsController < ApplicationController
    def show
      @github_access_token = current_org.github_access_token || current_org.build_github_access_token
    end
  end
end
