module Dokku
  module Postgres
    class Link < Dokku::Command
      DEFAULT_ENV_NAME = "DATABASE_URL"

      attr_reader :service, :app, :env_name, :restart

      def initialize(ssh_session, service:, app:, env_name: DEFAULT_ENV_NAME, restart: false)
        @ssh_session = ssh_session
        @service = service
        @app = app
        @env_name = env_name
        @restart = restart
      end

      def command
        cmd = "dokku postgres:link #{service} #{app}"
        cmd += " --alias #{env_name}" if env_name.present?
        cmd += " --no-restart" unless restart
        cmd
      end
    end
  end
end
