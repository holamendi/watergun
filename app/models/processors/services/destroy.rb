module Processors
  module Services
    class Destroy < Base
      def process
        execute("dokku #{action.service_type}:destroy #{action.dokku_id} --force")
      end
    end
  end
end
