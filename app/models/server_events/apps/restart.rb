module ServerEvents
  module Apps
    class Restart < Base
      def commands
        "dokku ps:restart #{app.dokku_id}"
      end
    end
  end
end
