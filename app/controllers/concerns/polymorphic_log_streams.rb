module PolymorphicLogStreams
  extend ActiveSupport::Concern

  included do
    before_action :set_log_stream, only: [:show, :update, :destroy]
  end

  def index
    @log_stream = log_streamable.log_streams.create!
  end

  def show
    @log_stream.touch(:last_ping_at)
    head :ok
  end

  def update
    stop_active_log_streams
    StartLogStreamJob.perform_later(@log_stream)
    head :ok
  end

  def destroy
    @log_stream.destroy
    StopLogStreamJob.perform_now(@log_stream.server, @log_stream.uuid)

    head :no_content
  end

  private

  def set_log_stream
    @log_stream = log_streamable.log_streams.find(params[:id])
  end

  def stop_active_log_streams
    log_streamable.log_streams.excluding(@log_stream).each do |log_stream|
      log_stream.destroy
      StopLogStreamJob.perform_later(log_stream.server, log_stream.uuid)
    end
  end

  def log_streamable
    raise "implement in subclass"
  end
end
