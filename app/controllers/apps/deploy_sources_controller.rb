module Apps
  class DeploySourcesController < BaseController
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
  end
end
