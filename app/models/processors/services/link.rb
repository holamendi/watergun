module Processors
  module Services
    class Link < Base
      delegate :service_type, :service_dokku_id, :app_dokku_id, :service_link_id, to: :action

      def process
        link_dokku_service
        service_link.status_linked!
      end

      private

      def link_dokku_service
        ssh.execute("dokku #{service_type}:link #{service_dokku_id} #{app_dokku_id} --no-restart")
      end

      def service_link
        service.service_links.find(service_link_id)
      end
    end
  end
end
