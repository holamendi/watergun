module Actions
  module Apps
    class Destroy < Base
      def commands
        "dokku apps:destroy --force #{app.dokku_id}"
      end
    end
  end
end
