module ActionProcessors
  module Apps
    class SetConfig < Base
      def process
        execute("dokku config:set --encoded --no-restart #{app.dokku_id} #{encoded_variables_as_string}")
      end

      private

      def encoded_variables_as_string
        encoded_variables = app.environment_configuration.variables.transform_values { |value| Base64.encode64(value) }
        encoded_variables.map { |key, value| "#{key}=\"#{value}\"" }.join(" ")
      end
    end
  end
end
