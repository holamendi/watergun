class Github::InstallationsController < ApplicationController
  def callback
    installation = api_client.installation(params[:installation_id])
    github_integration.update!(installation_id: installation.id)
    redirect_to account_path, notice: "Github App installed"
  rescue Octokit::NotFound
    flash[:error] = "Invalid installation id"
    redirect_to account_path
  end

  private

  def github_integration
    current_account.github_integration
  end

  def api_client
    Octokit::Client.new(bearer_token: github_integration.jwt)
  end
end
