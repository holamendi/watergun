module Actions
  module Apps
    class Deploy < Action
      store_attribute :payload, :dokku_app_id, :string

      validates :dokku_app_id, presence: true

      def perform
        result = rebuild_dokku_app
        return unless result.success?

        update_app_last_deployed_at(result.completed_at)
        enable_ssl
      end

      private

      def rebuild_dokku_app
        ssh.execute(Dokku::Ps.rebuild(dokku_app_id))
      end

      def update_app_last_deployed_at(timestamp)
        actionable.update_columns(last_deployed_at: timestamp)
      end

      def enable_ssl
        return if ssl_enabled?
        return unless actionable.urls_resolve_to_server?

        ssh.execute(Dokku::Plugins::Letsencrypt.enable(dokku_app_id))
      end

      def ssl_enabled?
        result = ssh.execute(Dokku::Plugins::Letsencrypt.active(dokku_app_id))
        result.success? && result.output.strip == "true"
      end
    end
  end
end
