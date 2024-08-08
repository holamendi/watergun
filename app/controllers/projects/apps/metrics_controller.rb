class Projects::Apps::MetricsController < Projects::Apps::BaseController
  include PolymorphicMetrics

  private

  def containerizable
    current_app
  end
end
