module ActionProcessors
  module Services
    class Restart < Base
      def process
        execute("dokku #{service.service_type}:restart #{service.dokku_id}")
      end
    end
  end
end
