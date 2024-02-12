module ActionProcessors
  module ServiceLinks
    class Destroy < Base
      def commands
        [
          "dokku service:unlink #{app.dokku_id} #{service.dokku_id}"
        ]
      end
    end
  end
end
