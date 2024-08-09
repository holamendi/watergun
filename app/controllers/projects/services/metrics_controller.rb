class Projects::Services::MetricsController < Projects::Services::BaseController
  include MetrizableController

  private

  def containerizable
    current_service
  end
end
