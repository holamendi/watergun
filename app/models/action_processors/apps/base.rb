module ActionProcessors
  module Apps
    class Base < ActionProcessors::Base
      alias_method :app, :actionable

      private

      def sync_app
        ssh_command = ssh.execute("dokku urls #{app.dokku_id}")
        return unless ssh_command.success?

        urls = ssh_command.text_output.split("\n")
        app.update!(urls:)
      end
    end
  end
end
