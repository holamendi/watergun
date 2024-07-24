module Accounts
  class UsersController < ApplicationController
    def update
      if current_user.update(user_params)
        render turbo_stream: notify("Profile updated successfully")
      else
        turbo_stream_form
      end
    end

    private

    def user_params
      params.require(:user).permit(:name)
    end

    def turbo_stream_form
      render turbo_stream: turbo_stream.replace(
        "user_form",
        partial: "accounts/users/form",
        locals: {
          user: current_user
        }
      )
    end
  end
end
