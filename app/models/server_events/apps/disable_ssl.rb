module ServerEvents
  module Apps
    class DisableSsl < Base
      def commands
        "dokku letsencrypt:disable #{app.dokku_id}"
      end
    end
  end
end
