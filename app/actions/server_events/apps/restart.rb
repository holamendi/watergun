module ServerEvents
  module Apps
    class Restart < Base
      def eventable_status
        "restarting"
      end

      def commands
        "dokku ps:restart #{app.dokku_name}"
      end
    end
  end
end
