module ServerEvents
  module Services
    class Destroy < Base
      def commands
        "dokku #{service.service_type}:destroy #{service.dokku_id} --force"
      end
    end
  end
end
