class Projects::Apps::LogStreamsController < Projects::Apps::BaseController
  include LogStreamableController

  private

  def log_streamable
    @app
  end
end
