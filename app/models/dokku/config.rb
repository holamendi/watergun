module Dokku
  class Config
    class << self
      def command_prefix(command)
        "dokku config:#{command}"
      end

      def set(app, env_variables, restart: false)
        command = command_prefix("set --encoded #{app} #{base_64_encoded_env_variables_as_string(env_variables)}")
        command += " --no-restart" unless restart
        command
      end

      private

      def base64_encoded_env_variables(env_variables)
        env_variables.transform_values { |value| Base64.encode64(value.to_s) }
      end

      def base_64_encoded_env_variables_as_string(env_variables)
        base64_encoded_env_variables(env_variables).map { |key, value| "#{key}=\"#{value}\"" }.join(" ")
      end
    end
  end
end
