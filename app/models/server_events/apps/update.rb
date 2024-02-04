module ServerEvents
  module Apps
    class Update < Base
      def commands
        [
          "dokku builder:set #{app.dokku_id} selected #{app.dokku_builder}"
        ]
      end
    end
  end
end
