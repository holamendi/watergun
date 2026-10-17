module Api
  module V1
    class PingsController < ApplicationController
      api_scope "apps:read", only: :show

      def show
        render json: {pong: true}
      end
    end
  end
end
