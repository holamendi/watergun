module ActionProcessors
  module Apps
    class Base < ActionProcessors::Base
      alias_method :app, :actionable

      private

      def sync_app
        ssh_command = execute("dokku urls #{app.dokku_id}")
        return unless ssh_command.success?

        urls = parse_app_urls(ssh_command.output)
        app.update!(urls:)
      end

      def parse_app_urls(text_output)
        text_output.split("\n")
      end
    end
  end
end
