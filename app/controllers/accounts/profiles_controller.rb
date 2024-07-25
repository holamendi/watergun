module Accounts
  class ProfilesController < ApplicationController
    def update
      if current_user.update(user_params)
        render turbo_stream: [
          notify("Profile updated"),
          render_form
        ]
      else
        render turbo_stream: render_form, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:name)
    end

    def render_form
      turbo_stream.replace("profile_form", partial: "accounts/profiles/form", locals: {user: current_user})
    end
  end
end
