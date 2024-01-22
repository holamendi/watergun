module ServerEvents
  module Services
    class Create < Base
      def app_status
        "creating"
      end

      def commands
        [
          "dokku apps:create #{app.dokku_name}",
          "dokku builder:set #{app.dokku_name} selected #{app.dokku_builder}"
        ]
      end
    end
  end
end
