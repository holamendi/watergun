module Processors
  module Apps
    class UpdateEnv < Base
      delegate :dokku_id, to: :action

      def process
        update_dokku_app_env
      end

      private

      def update_dokku_app_env
        ssh.execute("dokku config:set --encoded --no-restart #{dokku_id} #{base_64_encoded_env_variables_as_string}")
      end

      def base64_encoded_env_variables
        app.environment_configuration.variables.transform_values { |value| Base64.encode64(value) }
      end

      def base_64_encoded_env_variables_as_string
        base64_encoded_env_variables.map { |key, value| "#{key}=\"#{value}\"" }.join(" ")
      end
    end
  end
end
