module Projects
  module Apps
    class LogStreamsController < BaseController
      before_action :set_log_stream, only: [:show, :update, :destroy]

      def index
        @log_stream = current_app.log_streams.create!
      end

      def update
        Servers::LogStreamJob.perform_later(@log_stream)
        head :ok
      end

      def show
        @log_stream.touch(:last_ping_at)
        head :ok
      end

      def destroy
        Servers::StopLogStreamJob.perform_later(@log_stream)
        head :no_content
      end

      private

      def set_log_stream
        @log_stream = current_app.log_streams.find(params[:id])
      end
    end
  end
end
