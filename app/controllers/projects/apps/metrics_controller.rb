class Projects::Apps::MetricsController < Projects::Apps::BaseController
  include MetrizableController

  private

  def containerizable
    current_app
  end
end
