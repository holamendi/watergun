module Processors
  module Services
    class Unlink < Base
      def process
        unlink_service
      end

      private

      def unlink_service
        execute("dokku #{action.service_type}:unlink #{action.service_dokku_id} #{action.app_dokku_id} --no-restart")
      end
    end
  end
end
