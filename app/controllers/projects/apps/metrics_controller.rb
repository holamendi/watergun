class Projects::Apps::MetricsController < Projects::Apps::BaseController
  include MetrizableController

  private

  def containerizable
    @app
  end
end
