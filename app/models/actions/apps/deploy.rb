module Actions
  module Apps
    class Deploy < Action
      include DokkuAppAction

      def process_action
        result = rebuild_dokku_app
        return unless result.success?

        actionable.update_columns(last_deployed_at: rebuild_app_result.completed_at)

        sync_app

        enable_dokku_app_ssl
      end

      private
    end
  end
end
