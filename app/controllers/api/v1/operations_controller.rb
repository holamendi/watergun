module Api
  module V1
    class OperationsController < ApplicationController
      api_scope "operations:read", only: :show

      def show
        run = ServerActionRun.where(account: Current.account, action_key: ServerActionRun::PUBLIC_KINDS.keys)
          .where.not(request_id: nil).find(params[:id])
        render_operation(run)
      end
    end
  end
end
