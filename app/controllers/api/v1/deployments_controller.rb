class Api::V1::DeploymentsController < Api::V1::ApplicationController
  api_scope "apps:read", only: %i[index show]
  api_scope "deployments:write", only: :create

  before_action :set_app, :set_github_repo, only: [:create]

  def index
    set_app
    deployments = account_deployments.where(app_id: @app.id)
    render json: Api::V1::DeploymentResource.new(deployments)
  end

  def show
    deployment = if params[:app_id].present?
      set_app
      account_deployments.where(app_id: @app.id).find(params[:id])
    else
      account_deployments.find(params[:id])
    end

    render json: Api::V1::DeploymentResource.new(deployment)
  end

  def create
    deployment = Deployment::Creator.new(app: @app, commit_sha: params[:sha]).create!
    render json: Api::V1::DeploymentResource.new(deployment), status: :created
  rescue ActiveModel::ValidationError => e
    render json: {errors: e.model.errors.messages}, status: :unprocessable_content
  end

  private

  def account_deployments
    Current.account.deployments.kept.where(apps: {account_id: Current.account.id})
  end

  def set_app
    @app = Current.account.apps.kept.find(params[:app_id])
  end

  def set_github_repo
    @github_repo = @app.github_repo

    unless @github_repo.present?
      render json: {errors: ["Github repo not found"]}, status: :not_found
    end
  end
end
