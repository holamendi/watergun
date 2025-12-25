class Github::AppRegistrationsController < ApplicationController
  def callback
    unless valid_state?
      return redirect_to root_path, alert: "Invalid state parameter"
    end

    conversion_response = HTTP.post("https://api.github.com/app-manifests/#{params[:code]}/conversions")

    if conversion_response.code == 201
      github_app = create_github_app!(conversion_response)
      redirect_to github_app.new_installation_url, allow_other_host: true
    else
      flash[:error] = "Invalid manifest code"
      redirect_to account_path
    end
  end

  private

  def valid_state?
    Current.account = Account.find_signed!(params[:state], purpose: :github_app_registration)
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
