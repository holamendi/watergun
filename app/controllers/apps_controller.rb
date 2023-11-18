class AppsController < ApplicationController
  def index
    @apps = Current.server.apps
  end
end
