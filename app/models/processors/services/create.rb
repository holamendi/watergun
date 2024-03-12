module Processors
  module Services
    class Create < Base
      def process
        execute("dokku #{action.service_type}:create #{action.dokku_id}")
        service.update_columns(status: "created")
      end
    end
  end
end
