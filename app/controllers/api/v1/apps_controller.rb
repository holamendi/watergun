module Api
  module V1
    class AppsController < ApplicationController
      after_action { pagy_headers_merge(@pagy) if @pagy }

      def index
        @pagy, @apps = pagy(current_account.apps.kept)
        render json: AppResource.new(@apps)
      end

      def show
        app = current_account.apps.kept.find(params[:id])

        render json: AppResource.new(app)
      end
    end
  end
end
