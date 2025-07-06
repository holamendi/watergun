class Projects::Services::LogStreamsController < Projects::Services::BaseController
  include LogStreamableController

  private

  def log_streamable
    @service
  end
end
