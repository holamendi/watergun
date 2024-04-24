module Apps
  class DeploymentsController < BaseController
    def create
      @deployment = @app.deployments.new(deployment_params)

      if @deployment.save
        ServerActions::DeployDokkuApp.perform_later!(@deployment)
      else
        flash.now[:alert] = @deployment.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def deployment_params
      params.require(:deployment).permit(:branch, :ref)
    end
  end
end
