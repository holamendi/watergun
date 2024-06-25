module Projects
  module Apps
    class LogsController < BaseController
      def show
        @jid = StreamAppLogsJob.perform_later(current_app).job_id
        Rails.cache.write("stream_#{@jid}", true)
      end
    end
  end
end
