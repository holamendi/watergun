class Github::InstallationsController < ApplicationController
  def callback
    installation = github_integration.app_api_client.installation(params[:installation_id])
    github_integration.update!(installation_id: installation.id)
    redirect_to account_path, notice: "Github App installed"
  rescue Octokit::NotFound
    flash[:error] = "Invalid installation id"
    redirect_to account_path
  end

  def destroy
    github_integration.app_api_client.delete_installation(github_integration.installation_id)
    github_integration.update!(installation_id: nil)
    redirect_to account_path, notice: "Github App uninstalled"
  end

  private

  def github_integration
    current_account.github_integration
  end
end
