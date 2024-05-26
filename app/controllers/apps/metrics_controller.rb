module Apps
  class MetricsController < ApplicationController
    before_action :set_app

    def show
      @running_containers = @app.containers.running
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end
  end
end
