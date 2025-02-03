module Dokku
  module Services
    class LinkCommand
      SETTINGS = {
        mongo: {
          env_name: "MONGO_URL"
        },
        mysql: {
          env_name: "MYSQL_URL"
        },
        postgres: {
          env_name: "POSTGRES_URL"
        },
        redis: {
          env_name: "REDIS_URL"
        }
      }.freeze

      def initialize(plugin:, service:, app:, env_name: nil, restart: false)
        @plugin = plugin
        @service = service
        @app = app
        @env_name = env_name.presence || SETTINGS.dig(plugin.to_sym, :env_name)
        @restart = restart
      end

      def command
        cmd = "dokku #{@plugin}:link #{@service} #{@app}"
        cmd += " --alias #{@env_name}" if @env_name.present?
        cmd += " --no-restart" unless @restart
        cmd
      end
    end
  end
end
