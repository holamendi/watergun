module Api
  module V1
    class PingsController < ApplicationController
      def show
        render json: {ping: "pong"}
      end
    end
  end
end
