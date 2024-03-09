module Apps
  class DeploymentsController < BaseController
    def create
      @app.enqueue_action!(:deploy, dokku_id: @app.dokku_id)
      redirect_to @app, notice: "Deployment enqueued successfully."
    end
  end
end
