module Projects
  module Apps
    class LogsController < BaseController
      def show
        @log_stream_jid = Servers::LogStreamJob.perform_later(current_app).job_id
      end
    end
  end
end
