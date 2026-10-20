class Api::V1::DeploymentsController < Api::V1::ApplicationController
  def index
    deployments = Current.account.deployments.kept
    deployments = deployments.where(app_id: params[:app_id]) if params[:app_id].present?
    render json: Api::V1::DeploymentResource.new(deployments)
  end

  def show
    deployment = if params[:app_id].present?
      set_app
      @app.deployments.kept.find(params[:id])
    else
      Current.account.deployments.kept.find(params[:id])
    end

    render json: Api::V1::DeploymentResource.new(deployment)
  end

  private

  def set_app
    @app = Current.account.apps.kept.find(params[:app_id])
  end
end
