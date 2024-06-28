module Projects
  module Apps
    class BaseController < Projects::BaseController
      before_action :set_app

      helper_method :current_app

      def current_app
        Current.app
      end

      private

      def set_app
        Current.app = current_project.apps.kept.find(params[:app_id])
      end
    end
  end
end
