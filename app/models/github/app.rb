class Github::App < ApplicationRecord
  belongs_to :account
  has_many :installations, class_name: "Github::Installation", foreign_key: :github_app_id
  has_many :github_events, through: :installations

  def registered?
    github_id.present?
  end

  def app_manifest
    {
      name: "Watergun",
      description: "Yup",
      url: Rails.application.routes.url_helpers.root_url,
      public: false,
      redirect_url: Rails.application.routes.url_helpers.callback_github_registration_url,
      setup_url: Rails.application.routes.url_helpers.callback_github_installation_url,
      default_permissions: {
        checks: "read",
        contents: "read"
      },
      default_events: [
        "check_suite",
        "push"
      ],
      hook_attributes: {
        url: Rails.application.routes.url_helpers.github_events_url(installations.first&.token)
      }
    }
  end

  def app_api_client
    Octokit::Client.new(bearer_token: app_api_bearer_token)
  end

  def app_api_bearer_token
    payload = {
      iat: Time.now.to_i - 60,
      exp: Time.now.to_i + (10 * 60),
      iss: client_id
    }

    JWT.encode(payload, private_key, "RS256")
  end

  private

  def private_key
    OpenSSL::PKey::RSA.new(pem)
  end
end
