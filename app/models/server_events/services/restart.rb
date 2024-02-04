module ServerEvents
  module Services
    class Restart < Base
      def commands
        "dokku #{service.service_type}:restart #{service.dokku_id}"
      end
    end
  end
end
