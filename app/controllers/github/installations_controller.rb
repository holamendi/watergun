class Github::InstallationsController < ApplicationController
  def callback
    installation = github_app.api_client.installation(params[:installation_id])

    Github::Installation.create!(
      account: Current.account,
      github_app:,
      installation_id: installation.id,
      login: installation.account.login
    )

    redirect_to account_path, notice: "Github account connected"
  rescue Octokit::NotFound
    flash[:error] = "Invalid installation id"
    redirect_to account_path
  end

  def destroy
    github_installation = github_app.installations.find(params[:id])
    github_app.api_client.delete_installation(github_installation.installation_id)
    github_installation.destroy
    redirect_to account_path, notice: "Github App uninstalled"
  end

  private

  def github_app
    @github_app ||= Current.account.github_app
  end
end
