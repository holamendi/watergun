module ActionProcessors
  module Apps
    class Create < Base
      def process
        ssh.execute("dokku apps:create #{app.dokku_id}")
      end
    end
  end
end
