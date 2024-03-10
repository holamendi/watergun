module Processors
  module Apps
    class Base < Processors::Base
      alias_method :app, :actionable

      private

      def sync_app
        app.update_columns(urls: dokku_app_urls)
      end

      def dokku_app_urls
        execute("dokku urls #{action.dokku_id}").text_output.split("\n")
      end

      def enable_ssl
        return if ssl_enabled?
        return unless app.urls_resolve_to_server?

        execute("dokku letsencrypt:enable #{action.dokku_id}")
      end

      def ssl_enabled?
        execute("dokku letsencrypt:active #{action.dokku_id}").text_output.strip == "true"
      end
    end
  end
end
