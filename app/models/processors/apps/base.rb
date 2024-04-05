module Processors
  module Apps
    class Base < Processors::Base
      alias_method :app, :actionable
      delegate :dokku_id, to: :action

      private

      def sync_app
        app.update_columns(urls: dokku_app_urls)
      end

      def dokku_app_urls
        ssh.execute("dokku urls #{dokku_id}").text_output.split("\n")
      end

      def enable_ssl
        return if ssl_enabled?
        return unless app.urls_resolve_to_server?

        ssh.execute("dokku letsencrypt:enable #{dokku_id}")
      end

      def ssl_enabled?
        ssh.execute("dokku letsencrypt:active #{dokku_id}").text_output.strip == "true"
      end
    end
  end
end
