module Dokku
  module Config
    class SetCommand
      def initialize(app:, env:, restart: false)
        @app = app
        @env = env
        @restart = restart
      end

      def cmd
        cmd = "dokku config:set #{@app} #{base64_encoded_variables} --encoded"
        cmd += " --no-restart" unless @restart
        cmd
      end

      def sensitive_output?
        true
      end

      def redacted_cmd
        cmd = "dokku config:set #{@app} [FILTERED] --encoded"
        cmd += " --no-restart" unless @restart
        cmd
      end

      private

      def base64_encoded_variables
        @env.map { |key, value| "#{key}=\"#{Base64.encode64(value.to_s)}\"" }.join(" ")
      end
    end
  end
end
