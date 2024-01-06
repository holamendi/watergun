module ServerEvents
  module Apps
    class Destroy < Base
      def commands
        "dokku apps:destroy --force #{app.dokku_name}"
      end
    end
  end
end
