module ActionProcessors
  module ServiceLinks
    class Destroy < Base
      def process
        ssh.execute("dokku service:unlink #{app.dokku_id} #{service.dokku_id}")
      end
    end
  end
end
