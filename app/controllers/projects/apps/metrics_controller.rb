class Projects::Apps::MetricsController < Projects::Apps::BaseController
  include PolymorphicMetrics

  private

  def containarizable
    current_app
  end
end
