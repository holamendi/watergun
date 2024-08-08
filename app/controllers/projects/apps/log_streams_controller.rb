class Projects::Apps::LogStreamsController < Projects::Apps::BaseController
  include PolymorphicLogStreams

  private

  def log_streamable
    current_app
  end
end
