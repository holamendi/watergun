class Projects::Services::LogStreamsController < Projects::Services::BaseController
  before_action :set_log_stream, only: [:show, :update, :destroy]

  def index
    @log_stream = current_service.log_streams.create!
  end

  def show
    @log_stream.touch(:last_ping_at)
    head :ok
  end

  def update
    current_service.log_streams.excluding(@log_stream).each do |log_stream|
      StopLogStreamJob.perform_later(log_stream)
    end

    StartLogStreamJob.perform_later(@log_stream)
    head :ok
  end

  def destroy
    StopLogStreamJob.perform_now(@log_stream)
    head :no_content
  end

  private

  def set_log_stream
    @log_stream = current_service.log_streams.find(params[:id])
  end
end
