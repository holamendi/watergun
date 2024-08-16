class Projects::Services::BaseController < Projects::BaseController
  before_action :set_service

  private

  def set_service
    @service = @project.services.kept.find(params[:service_id])
  end
end
