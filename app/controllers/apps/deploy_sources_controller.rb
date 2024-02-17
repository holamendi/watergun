module Apps
  class DeploySourcesController < ApplicationController
    before_action :set_app

    def new
      @deploy_source = DeploySources::Github.new(app: @app)
    end

    def create
      @deploy_source = DeploySources::Github.new(deploy_source_github_params.merge(app: @app))
      if @deploy_source.save
        redirect_to @app, notice: "App source created successfully."
      else
        render :new
      end
    end

    private

    def deploy_source_github_params
      params.require(:deploy_source).permit(:repository, :branch)
    end

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end
  end
end
