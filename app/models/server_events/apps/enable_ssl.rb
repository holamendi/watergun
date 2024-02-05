module ServerEvents
  module Apps
    class EnableSsl < Base
      def commands
        "dokku letsencrypt:enable #{app.dokku_id}"
      end
    end
  end
end
