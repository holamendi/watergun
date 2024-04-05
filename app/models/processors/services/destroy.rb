module Processors
  module Services
    class Destroy < Base
      delegate :dokku_id, :service_type, to: :action

      def process
        ssh.execute("dokku #{action.service_type}:destroy #{action.dokku_id} --force")
      end
    end
  end
end
