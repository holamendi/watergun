module ServerEvents
  module Apps
    class Update < Base
      def commands
        [
          "dokku builder:set #{app.dokku_name} selected #{app.dokku_builder}"
        ]
      end
    end
  end
end
