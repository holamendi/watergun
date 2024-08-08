class Projects::Services::MetricsController < Projects::Services::BaseController
  include PolymorphicMetrics

  private

  def containarizable
    current_service
  end
end
