class Projects::Services::MetricsController < Projects::Services::BaseController
  include MetrizableController

  private

  def containerizable
    @service
  end
end
