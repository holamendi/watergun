module Dokku
  module Config
    class UnsetCommand
      def initialize(app:, variable_names:, restart: false)
        @app = app
        @variable_names = Array(variable_names)
        @restart = restart
      end

      def cmd
        cmd = "dokku config:unset #{@app} #{@variable_names.join(" ")}"
        cmd += " --no-restart" unless @restart
        cmd
      end
    end
  end
end
