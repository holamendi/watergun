module ActionProcessors
  module Apps
    class Deploy < Base
      def process
        return unless rebuild_dokku_app.success?

        enable_ssl
        sync_app
      end

      private

      def rebuild_dokku_app
        result = ssh.execute("dokku ps:rebuild #{action.dokku_id}")
        app.update_columns(last_deployed_at: result.completed_at) if result.success?
        result
      end
    end
  end
end
