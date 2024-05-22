module Api
  module V1
    class PingsController < ApplicationController
      def show
        render json: {pong: true}
      end
    end
  end
end
