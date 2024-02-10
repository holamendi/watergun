module Actions
  module Services
    class Create < Base
      def commands
        [
          "dokku #{service.service_type}:create #{service.dokku_id}"
        ]
      end
    end
  end
end
