module Apps
  class DeploymentsController < BaseController
    def create
      @app.schedule_action!(
        Actions::Apps::Deploy,
        dokku_app_id: @app.dokku_id,
        repo: @app.deploy_source.repository,
        branch: @app.deploy_source.branch
      )
      redirect_to @app, notice: "Deployment enqueued successfully."
    end
  end
end
