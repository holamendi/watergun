module Actions
  module Apps
    class Deploy < Action
      store_attribute :payload, :dokku_app_id, :string
      store_attribute :payload, :repo, :string
      store_attribute :payload, :branch, :string

      validates :dokku_app_id, presence: true

      def perform
        return unless sync_github_repo.success?

        rebuild_result = rebuild_dokku_app
        return unless rebuild_result.success?

        update_app_last_deployed_at(rebuild_result.completed_at)
        enable_ssl
      end

      private

      def sync_github_repo
        ssh.execute(
          Dokku::Git.sync(
            dokku_app_id, repo: repo_url, branch:
          )
        )
      end

      def repo_url
        "https://github.com/#{repo}.git"
      end

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
        result.success? && result.text_output.strip == "true"
      end
    end
  end
end
