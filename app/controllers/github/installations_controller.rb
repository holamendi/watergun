class Github::InstallationsController < ApplicationController
  def callback
    installation = app_api_client.installation(params[:installation_id])
    github_integration.install!(installation_id: installation.id, account_login: installation.account.login)
    redirect_to account_path, notice: "Github App installed"
  rescue Octokit::NotFound
    flash[:error] = "Invalid installation id"
    redirect_to account_path
  end

  def destroy
    app_api_client.delete_installation(github_integration.installation_id)
    github_integration.uninstall!
    redirect_to account_path, notice: "Github App uninstalled"
  end

  private

  def github_integration
    current_account.github_integration
  end

  def app_api_client
    github_integration.app_api_client
  end
end
