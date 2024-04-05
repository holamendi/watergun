module Processors
  module Services
    class Create < Base
      def process
        create_dokku_service
        service.update_columns(status: "created")
      end

      private

      def create_dokku_service
        ssh.execute("dokku #{action.service_type}:create #{action.dokku_id}")
      end
    end
  end
end
