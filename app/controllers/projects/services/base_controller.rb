class Projects::Services::BaseController < Projects::BaseController
  before_action :set_service

  private

  def set_service
    @service = @project.services.kept.includes(:linked_apps, :server).find(params[:service_id])
  end
end
