module ActionProcessors
  module Services
    class Destroy < Base
      def process
        execute("dokku #{service.service_type}:destroy #{service.dokku_id} --force")
      end
    end
  end
end
