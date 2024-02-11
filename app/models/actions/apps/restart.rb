module Actions
  module Apps
    class Restart < Base
      def commands
        "dokku ps:restart #{actionable.dokku_id}"
      end
    end
  end
end
