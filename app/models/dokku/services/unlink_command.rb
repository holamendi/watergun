module Dokku
  module Services
    class UnlinkCommand
      def initialize(plugin:, service:, app:, restart: false)
        @plugin = plugin
        @service = service
        @app = app
        @restart = restart
      end

      def cmd
        cmd = "dokku #{@plugin}:unlink #{@service} #{@app}"
        cmd += " --no-restart" unless @restart
        cmd
      end
    end
  end
end
