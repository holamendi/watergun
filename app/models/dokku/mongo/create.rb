module Dokku
  module Mongo
    class CreateCommand
      def initialize(service:)
        @service = service
      end

      def command
        "dokku mongo:create #{@service}"
      end
    end
  end
end
