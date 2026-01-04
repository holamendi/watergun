module Accounts
  class ThemesController < ApplicationController
    def update
      if Current.user.update(theme_params)
        render turbo_stream: [
          stream_toast("Theme updated"),
          render_form
        ]
      else
        render turbo_stream: render_form, status: :unprocessable_content
      end
    end

    private

    def theme_params
      params.require(:user).permit(:theme)
    end

    def render_form
      turbo_stream.replace("theme_form", partial: "accounts/themes/form", locals: {user: Current.user})
    end
  end
end
