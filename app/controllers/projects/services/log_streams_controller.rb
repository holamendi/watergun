class Projects::Services::LogStreamsController < Projects::Services::BaseController
  include PolymorphicLogStreams

  private

  def log_streamable
    current_service
  end
end
