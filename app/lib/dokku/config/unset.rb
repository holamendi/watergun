module Dokku
  module Config
    class Unset < Dokku::Command
      attr_reader :app, :variable_names, :restart

      def initialize(ssh_session, app:, variable_names:, restart: false)
        @ssh_session = ssh_session
        @app = app
        @variable_names = Array(variable_names)
        @restart = restart
      end

      def command
        cmd = "dokku config:unset #{app} #{variable_names.join(" ")}"
        cmd += " --no-restart" unless restart
        cmd
      end
    end
  end
end
