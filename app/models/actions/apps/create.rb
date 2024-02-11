module Actions
  module Apps
    class Create < Base
      def commands
        "dokku apps:create #{actionable.dokku_id}"
      end
    end
  end
end
