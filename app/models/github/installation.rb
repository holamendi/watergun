class Github::Installation < ApplicationRecord
  has_secure_token :token, length: 32

  belongs_to :github_app, class_name: "Github::App"
  belongs_to :account
  has_many :github_events, class_name: "Github::Event", foreign_key: :github_installation_id

  def installed?
    installation_id.present?
  end

  def install!(installation_id:, account_login:)
    update!(installation_id:, account_login:)
  end

  def uninstall!
    update!(installation_id: nil, account_login: nil, access_token: nil, expires_at: nil)
  end

  def api_client
    Octokit::Client.new(access_token:)
  end

  def access_token
    refresh_access_token! if access_token_expired?
    super
  end

  def refresh_access_token!
    token = github_app.app_api_client.create_app_installation_access_token(installation_id)
    update!(access_token: token.token, expires_at: Time.at(token.expires_at))
  end

  def access_token_expired?
    expires_at.nil? || expires_at < Time.now
  end
end
