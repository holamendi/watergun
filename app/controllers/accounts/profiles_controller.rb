module Accounts
  class ProfilesController < ApplicationController
    def update
      sleep 2
      if Current.user.update(user_params)
        render turbo_stream: [
          stream_toast("Setting saved"),
          render_form
        ]
      else
        render turbo_stream: render_form, status: :unprocessable_content
      end
    end

    private

    def user_params
      params.require(:user).permit(:name)
    end

    def render_form
      turbo_stream.replace("profile_form", partial: "accounts/profiles/form", locals: {user: Current.user})
    end
  end
end
