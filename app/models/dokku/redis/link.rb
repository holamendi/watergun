module Dokku
  module Redis
    class Link
      DEFAULT_ENV_NAME = "REDIS_URL"

      attr_reader :service, :app, :env_name, :restart

      def initialize(ssh_session, service:, app:, env_name: DEFAULT_ENV_NAME, restart: false)
        @ssh_session = ssh_session
        @service = service
        @app = app
        @env_name = env_name
        @restart = restart
      end

      def command
        cmd = "dokku redis:link #{service} #{app}"
        cmd += " --alias #{env_name}" if env_name.present?
        cmd += " --no-restart" unless restart
        cmd
      end
    end
  end
end
