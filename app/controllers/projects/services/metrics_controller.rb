class Projects::Services::MetricsController < Projects::Services::BaseController
  include PolymorphicMetrics

  private

  def containerizable
    current_service
  end
end
