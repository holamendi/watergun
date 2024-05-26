module Apps
  class RestartsController < ApplicationController
    before_action :set_app

    def create
      ServerActions::RestartApp.perform_later!(@app)
      redirect_to @app, notice: "App restart scheduled successfully."
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end
  end
end
