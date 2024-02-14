module ActionProcessors
  module Services
    class Create < Base
      def process
        execute("dokku #{service.service_type}:create #{service.dokku_id}")
      end
    end
  end
end
