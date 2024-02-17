module ActionProcessors
  module Apps
    class Deploy < Base
      def process
        result = rebuild_app
        return unless result.success?

        app.update_columns(last_deployed_at: result.completed_at)
        sync_app
        attempt_ssl_cerficate_request
      end

      private

      def rebuild_app
        execute("dokku ps:rebuild #{app.dokku_id}")
      end
    end
  end
end
