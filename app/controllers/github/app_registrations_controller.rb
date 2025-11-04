class Github::AppRegistrationsController < ApplicationController
  def callback
    verify_state_param
    conversion_response = HTTPX.post("https://api.github.com/app-manifests/#{params[:code]}/conversions")

    if conversion_response.status == 201
      github_app = create_github_app!(conversion_response)
      redirect_to github_app.new_installation_url, allow_other_host: true
    else
      flash[:error] = "Invalid manifest code"
      redirect_to account_path
    end
  end

  private

  def verify_state_param
    account_from_state = Account.find_signed!(params[:state], purpose: :github_app_registration)
    return if Current.account == account_from_state

    flash[:error] = "Invalid state"
    redirect_to account_path
  end

  def create_github_app!(conversion_response)
    data = JSON.parse(conversion_response.body)

    Current.account.create_github_app!(
      app_id: data["id"],
      name: data["name"],
      slug: data["slug"],
      html_url: data["html_url"],
      client_id: data["client_id"],
      client_secret: data["client_secret"],
      pem: data["pem"],
      webhook_secret: data["webhook_secret"],
      permissions: data["permissions"],
      events: data["events"]
    )
  end
end
