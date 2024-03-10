module Processors
  module Services
    class Create < Base
      def process
        execute("dokku #{action.service_type}:create #{action.dokku_id}")
      end
    end
  end
end
