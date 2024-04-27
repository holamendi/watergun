module Apps
  class BaseController < ApplicationController
    before_action :set_app

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end
  end
end
