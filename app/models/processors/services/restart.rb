module Processors
  module Services
    class Restart < Base
      def process
        execute("dokku #{action.service_type}:restart #{action.dokku_id}")
      end
    end
  end
end
