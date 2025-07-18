class Github::InstallationsController < ApplicationController
  def create
    cookies[:after_install_return_to] = request.referer
    redirect_to "#{github_app.url}/installations/new", allow_other_host: true
  end

  def callback
    installation = app_api_client.installation(params[:installation_id])
    github_installation = github_app.installations.create!(
      account: Current.account,
      installation_id: installation.id,
      account_login: installation.account.login
    )
    redirect_to after_install_return_to, notice: "Github account connected"
  rescue Octokit::NotFound
    flash[:error] = "Invalid installation id"
    redirect_to account_path
  end

  def destroy
    github_installation = github_app.installations.first
    app_api_client.delete_installation(github_installation.installation_id) if github_installation
    github_installation&.destroy
    redirect_to account_path, notice: "Github App uninstalled"
  end

  private

  def github_app
    Current.account.github_app
  end

  def app_api_client
    github_app.app_api_client
  end

  def after_install_return_to
    cookies.delete(:after_install_return_to) || account_path
  end
end
