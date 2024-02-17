module ActionProcessors
  module Apps
    class Base < ActionProcessors::Base
      alias_method :app, :actionable

      private

      def sync_app
        ssh_command = execute("dokku urls #{app.dokku_id}")
        return unless ssh_command.success?

        urls = parse_app_urls(ssh_command.text_output)
        app.update_columns(urls:)
      end

      def attempt_ssl_cerficate_request
        return if letsencrypt_enabled?
        return unless app.urls.all? { |url| Resolv.getaddress(URI.parse(url).host) == server.public_ip }

        execute("dokku letsencrypt:enable #{app.dokku_id}")
        sync_app
      end

      def letsencrypt_enabled?
        execute("dokku letsencrypt:active #{app.dokku_id}").text_output.strip == "true"
      end

      def parse_app_urls(text_output)
        text_output.split("\n")
      end
    end
  end
end
