module Processors
  module Services
    class Link < Base
      def process
        link_service
        update_service_link_status
      end

      private

      def link_service
        execute("dokku #{action.service_type}:link #{action.service_dokku_id} #{action.app_dokku_id}")
      end

      def update_service_link_status
        service.service_links.find(action.service_link_id).update_columns(status: "linked")
      end
    end
  end
end
