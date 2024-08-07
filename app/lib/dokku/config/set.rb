module Dokku
  module Config
    class Set < Dokku::Command
      attr_reader :app, :env, :restart

      def initialize(ssh_session, app:, env:, restart: false)
        @ssh_session = ssh_session
        @app = app
        @env = env
        @restart = restart
      end

      def command
        cmd = "dokku config:set #{app} #{base64_encoded_variables} --encoded"
        cmd += " --no-restart" unless restart
        cmd
      end

      private

      def base64_encoded_variables
        env.map { |key, value| "#{key}=\"#{Base64.encode64(value.to_s)}\"" }.join(" ")
      end
    end
  end
end
