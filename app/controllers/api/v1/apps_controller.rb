module Api
  module V1
    class AppsController < ApplicationController
      def index
        apps = current_org.apps.kept

        render json: AppResource.new(apps)
      end

      def show
        app = current_org.apps.kept.find(params[:id])

        render json: AppResource.new(app)
      end
    end
  end
end
