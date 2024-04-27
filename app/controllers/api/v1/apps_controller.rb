module Api
  module V1
    class AppsController < ApplicationController
      def index
        render json: current_user.apps
      end
    end
  end
end
