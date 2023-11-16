module ServerEvents
  module Apps
    class Restart < ApplicationService
      def initialize(app)
        @app = app
      end

      def call
      end
    end
  end
end
