class Api::V1::DeploymentsController < Api::V1::ApplicationController
  api_scope "apps:read", only: %i[index show]
  api_scope "deployments:write", only: :create

  def index
    set_app
    deployments = page_records(account_deployments.where(app_id: @app.id))
    render json: Api::V1::DeploymentResource.new(deployments) unless performed?
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
    body = mutation_body
    return if performed?
    raise ServerAction::Accept::Error, "invalid_request" unless (body.keys - %w[sha]).empty?
    if body.key?("sha") && !(body["sha"].is_a?(String) && body["sha"].match?(/\A[0-9a-fA-F]{40}\z/))
      raise ServerAction::Accept::Error, "validation_failed"
    end
    prepare = lambda do
      app = account_apps.find(request.path_parameters[:app_id])
      usable_app!(app)
      source_prerequisites!(app)
      source_prerequisites_for_deployment!(app)
      begin
        app.account.github_installation.api_client.repo(app.github_repo.repo)
      rescue Octokit::NotFound, Octokit::InvalidRepository
        raise ServerAction::Accept::Error, "prerequisite_missing"
      end
      command = Deployment::CreateDeployment.new(app: app, commit_sha: body["sha"], builder: app.builder)
      raise ServerAction::Accept::Error, "validation_failed" unless command.prepare
      command
    end
    accept_operation(App.new(id: request.path_parameters[:app_id]), endpoint: "POST /api/v1/apps/:app_id/deployments",
      body: body, scope: "deployments:write", prepare: prepare) do |app, command|
      usable_app!(app)
      source_prerequisites!(app)
      source_prerequisites_for_deployment!(app)
      command.app = app
      command.save!(enqueue: false)
      command.server_action_run
    end
  rescue Octokit::Error, Faraday::Error
    raise ServerAction::Accept::Error, "unavailable"
  end

  private

  def account_deployments
    Current.account.deployments.kept.where(apps: {account_id: Current.account.id})
  end

  def set_app
    @app = account_apps.find(params[:app_id])
  end

  def source_prerequisites_for_deployment!(app)
    repo = app.github_repo
    unless repo && repo.account_id == Current.account.id && repo.repo.present? && repo.branch.present? && app.server.available_dokku_builders.key?(app.builder)
      raise ServerAction::Accept::Error, "prerequisite_missing"
    end
  end
end
