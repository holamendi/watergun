class Projects::Apps::BaseController < Projects::BaseController
  before_action :set_app

  private

  def set_app
    @app = @project.apps.kept.includes(:services, :server, :github_repo, :default_domain).find(params[:app_id])
  end
end
