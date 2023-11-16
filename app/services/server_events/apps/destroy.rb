module ServerEvents
  module Apps
    class Destroy < ApplicationService
      def initialize(app)
        @app = app
      end

      def call
      end
    end
  end
end
