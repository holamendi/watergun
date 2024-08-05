class Projects::Services::BaseController < Projects::BaseController
  before_action :set_service

  helper_method :current_service

  def current_service
    Current.service
  end

  private

  def set_service
    Current.service = current_project.services.kept.find(params[:service_id])
  end
end
