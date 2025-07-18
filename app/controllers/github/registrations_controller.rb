class Github::RegistrationsController < ApplicationController
  def callback
    response = HTTPX.post("https://api.github.com/app-manifests/#{params[:code]}/conversions")

    if response.status == 201
      json = JSON.parse(response.body)

      github_app.update!(
        github_id: json["id"],
        slug: json["slug"],
        url: json["html_url"],
        client_id: json["client_id"],
        pem: json["pem"],
        webhook_secret: json["webhook_secret"],
        permissions: json["permissions"],
        events: json["events"]
      )

      # Create installation record
      github_app.installations.create!(
        account: Current.account,
        installation_id: json["installation_id"]
      )

      redirect_to "#{github_app.url}/installations/new", allow_other_host: true
    else
      flash[:error] = "Invalid manifest code"
      redirect_to account_path
    end
  end

  private

  def github_app
    Current.account.github_app
  end
end
