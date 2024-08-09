class Projects::Apps::LogStreamsController < Projects::Apps::BaseController
  include LogStreamableController

  private

  def log_streamable
    current_app
  end
end
