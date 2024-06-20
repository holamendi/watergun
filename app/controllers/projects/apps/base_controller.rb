module Projects
  module Apps
    class BaseController < Projects::BaseController
      before_action :set_app

      helper_method :current_app

      def current_app
        @app
      end

      private

      def set_app
        @app = current_project.app
      end
    end
  end
end
