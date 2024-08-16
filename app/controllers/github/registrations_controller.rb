class Github::RegistrationsController < ApplicationController
  def callback
    response = HTTPX.post("https://api.github.com/app-manifests/#{params[:code]}/conversions")

    if response.status == 201
      json = JSON.parse(response.body)

      github_integration.update!(
        app_id: json["id"],
        app_slug: json["slug"],
        app_url: json["html_url"],
        client_id: json["client_id"],
        pem: json["pem"],
        webhook_secret: json["webhook_secret"],
        installation_id: json["installation_id"],
        permissions: json["permissions"],
        events: json["events"]
      )

      redirect_to "#{github_integration.app_url}/installations/new", allow_other_host: true
    else
      flash[:error] = "Invalid manifest code"
      redirect_to account_path
    end
  end

  private

  def github_integration
    Current.account.github_integration
  end
end
