class Accounts::GithubAppsController < ApplicationController
  def create
    @github_app = Current.account.github_app || Current.account.build_github_app(github_app_params)

    if @github_app.save
      render turbo_stream: [stream_toast("Github account connected"), render_form]
    else
      render turbo_stream: render_form, status: :unprocessable_entity
    end
  end

  def destroy
    Current.account.github_app&.destroy
    render turbo_stream: [
      stream_toast("Github account disconnected"),
      render_form
    ]
  end

  private

  def github_app_params
    params.require(:github_app).permit(:github_id, :client_id, :slug, :url, :pem, :webhook_secret, :permissions, :events)
  end

  def render_form
    turbo_stream.replace(
      "github_app_settings",
      partial: "accounts/github_apps/settings",
      locals: {
        github_app: @github_app || Current.account.github_app || Current.account.build_github_app
      }
    )
  end
end
