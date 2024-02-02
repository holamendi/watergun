module ServerEvents
  module Apps
    class Update < Base
      def self.evaluate(app:)
        return unless app.saved_change_to_dokku_builder?
        debugger
        app.create_server_event!("update")
      end

      def commands
        [
          "dokku builder:set #{app.dokku_name} selected #{app.dokku_builder}"
        ]
      end
    end
  end
end
