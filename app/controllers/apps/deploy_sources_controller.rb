module Apps
  class DeploySourcesController < ApplicationController
    before_action :set_app

    def create
      @app_source = DeploySources::Github.new(app_source_params.merge(app: @app))

      if @app_source.save
        redirect_to @app, notice: "App source created successfully."
      else
        render :new
      end
    end

    private

    def app_source_params
      params.require(:app_source).permit(:repository, :branch)
    end

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def set_app_source
      @app_source = @app.sources.find(params[:id])
    end
  end
end
