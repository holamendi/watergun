module ActionProcessors
  module Apps
    class Base < ActionProcessors::Base
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
        return unless app_domains_resolve_to_server?

        execute("dokku letsencrypt:enable #{app.dokku_id}")
      end

      def ssl_enabled?
        execute("dokku letsencrypt:active #{app.dokku_id}").text_output.strip == "true"
      end

      def app_domains_resolve_to_server?
        app.urls.all? { |url| Resolv.getaddress(URI.parse(url).host) == server.public_ip }
      end
    end
  end
end
