class Api::V1::ProjectsController < Api::V1::ApplicationController
  api_scope "apps:read", only: :index

  def index
    projects = page_records(account_projects)
    return if performed?

    render json: Api::V1::ProjectResource.new(projects)
  end
end
