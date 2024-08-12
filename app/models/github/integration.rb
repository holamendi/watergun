class Github::Integration < ApplicationRecord
  has_secure_token :token

  belongs_to :account, default: -> { Current.account }
  has_many :github_events, class_name: "Github::Event", foreign_key: :github_integration_id

  # app attributes
  store_attribute :data, :app_id, :integer
  store_attribute :data, :app_slug, :string
  store_attribute :data, :app_url, :string
  store_attribute :data, :client_id, :string
  store_attribute :data, :pem, :string
  store_attribute :data, :webhook_secret, :string
  store_attribute :data, :permissions, :json
  store_attribute :data, :events, :json

  # installation attributes
  store_attribute :data, :installation_id, :integer
  store_attribute :data, :installation_account_login, :string
  store_attribute :data, :access_token, :string
  store_attribute :data, :access_token_expires_at, :datetime

  def app_registered?
    app_id.present?
  end

  def app_installed?
    installation_id.present?
  end

  def install!(installation_id:, account_login:)
    update!(installation_id:, installation_account_login: account_login)
  end

  def uninstall!
    update!(installation_id: nil, installation_account_login: nil, access_token: nil, access_token_expires_at: nil)
  end

  def api_client
    Octokit::Client.new(access_token:)
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

  def access_token
    refresh_access_token! if access_token_expired?
    super
  end

  def refresh_access_token!
    token = app_api_client.create_app_installation_access_token(installation_id)
    update!(access_token: token.token, access_token_expires_at: Time.at(token.expires_at))
  end

  def access_token_expired?
    access_token_expires_at.nil? || access_token_expires_at < Time.now
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
        url: Rails.application.routes.url_helpers.github_events_url(token)
      }
    }
  end

  private

  def private_key
    OpenSSL::PKey::RSA.new(pem)
  end
end
