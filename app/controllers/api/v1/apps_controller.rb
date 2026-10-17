class Api::V1::AppsController < Api::V1::ApplicationController
  api_scope "apps:read", only: %i[index show]
  api_scope "apps:write", only: %i[create restart destroy]

  def index
    apps = account_apps
    apps = apps.where(project_id: account_projects.find(params[:project_id]).id) if params[:project_id]
    apps = page_records(apps)
    render json: Api::V1::AppResource.new(apps) unless performed?
  end

  def show
    app = account_apps.find(params[:id])
    render json: Api::V1::AppResource.new(app)
  end

  def create
    body = mutation_body
    return if performed?
    source = body["source"]
    unless (body.keys - %w[name source builder]).empty? && source.is_a?(Hash) && (source.keys - %w[type repo branch]).empty?
      raise ServerAction::Accept::Error, "invalid_request"
    end
    builder = body.fetch("builder", "herokuish")
    branch = source["branch"]
    valid_branch = branch.is_a?(String) && branch.length.between?(1, 255) &&
      !branch.match?(/[\x00-\x20\x7f~^:?*\[\\]/) && !branch.include?("..") && !branch.include?("@{") &&
      !branch.start_with?("-", "/") && !branch.end_with?("/", ".") && branch != "@" &&
      branch.split("/", -1).all? { |part| part.present? && !part.start_with?(".") && !part.end_with?(".lock") }
    unless body["name"].is_a?(String) && body["name"].length.between?(1, 100) && body["name"].match?(/\A[A-Za-z0-9][A-Za-z0-9 _-]*\z/) &&
        source["type"] == "github" && source["repo"].is_a?(String) && source["repo"].match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/) &&
        valid_branch && App.builders.key?(builder)
      raise ServerAction::Accept::Error, "validation_failed"
    end
    body["builder"] = builder
    prepare = lambda do
      project = account_projects.find(request.path_parameters[:project_id])
      source_prerequisites!(project)
      raise ServerAction::Accept::Error, "prerequisite_missing" unless project.server.available_dokku_builders.key?(builder)
      command = App::CreateApp.new(project: project, name: body["name"], repo: source["repo"], branch: branch, builder: builder)
      unless command.valid?
        code = command.errors.include?(:repo) ? "prerequisite_missing" : "validation_failed"
        raise ServerAction::Accept::Error, code
      end
      [command, project.server_id, project.account.github_installation.id]
    end
    accept_operation(Project.new(id: request.path_parameters[:project_id]), endpoint: "POST /api/v1/projects/:id/apps",
      body: body, scope: "apps:write", prepare: prepare) do |project, prepared|
      command, server_id, installation_id = prepared
      source_prerequisites!(project)
      unless project.server_id == server_id && project.account.github_installation.id == installation_id && project.server.available_dokku_builders.key?(builder)
        raise ServerAction::Conflict::Error
      end
      command.project = project
      raise ServerAction::Accept::Error, "validation_failed" unless command.save
      command.app.server_action_run
    end
  rescue Octokit::Error, Faraday::Error
    raise ServerAction::Accept::Error, "unavailable"
  end

  def restart
    return api_error("invalid_request", :bad_request) unless request.raw_post.empty? && request.query_parameters.empty?
    accept_operation(App.new(id: params[:id]), endpoint: "POST /api/v1/apps/:id/restarts", scope: "apps:write") do |app|
      usable_app!(app, deployed: true)
      ServerAction::Enqueue.call(action: "apps.restart", target: app)
    end
  end

  def destroy
    return api_error("invalid_request", :bad_request) unless request.raw_post.empty? && request.query_parameters.empty?
    accept_operation(App.new(id: params[:id]), endpoint: "DELETE /api/v1/apps/:id", scope: "apps:write") do |app|
      usable_app!(app)
      App::DestroyApp.new(app).destroy
    end
  end
end
