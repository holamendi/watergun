class Projects::Apps::BaseController < Projects::BaseController
  before_action :set_app

  private

  def set_app
    @app = @project.apps.kept.find(params[:app_id])
  end
end
