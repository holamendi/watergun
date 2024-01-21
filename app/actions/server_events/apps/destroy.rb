module ServerEvents
  module Apps
    class Destroy < Base
      def eventable_status
        "destroying"
      end

      def commands
        "dokku apps:destroy --force #{app.dokku_name}"
      end
    end
  end
end
