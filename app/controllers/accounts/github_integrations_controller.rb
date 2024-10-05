class Accounts::GithubIntegrationsController < ApplicationController
  def create
    @github_integration = Current.account.build_github_integration(github_integration_params)

    if @github_integration.save
      render turbo_stream: [append_toast("Github account connected"), render_form]
    else
      render turbo_stream: render_form, status: :unprocessable_entity
    end
  end

  def destroy
    Current.account.github_integration&.destroy
    render turbo_stream: [
      append_toast("Github account disconnected"),
      render_form
    ]
  end

  private

  def github_integration_params
    params.require(:github_integration).permit(:personal_access_token)
  end

  def render_form
    turbo_stream.replace(
      "github_integration_settings",
      partial: "accounts/github_integrations/settings",
      locals: {
        github_integration: @github_integration || Current.account.build_github_integration
      }
    )
  end
end
