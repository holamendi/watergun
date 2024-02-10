module Actions
  module Apps
    class Create < Base
      def commands
        [
          "dokku apps:create #{app.dokku_id}",
          "dokku builder:set #{app.dokku_id} selected #{app.dokku_builder}"
        ]
      end
    end
  end
end
