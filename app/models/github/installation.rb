class Github::Installation < ApplicationRecord
  encrypts :access_token

  belongs_to :account
  belongs_to :github_app, class_name: "Github::App"
  has_many :access_tokens, class_name: "Github::InstallationAccessToken", foreign_key: :github_installation_id, inverse_of: :installation, dependent: :destroy
  has_many :events, class_name: "Github::Event", foreign_key: :github_installation_id, inverse_of: :installation, dependent: :destroy

  def api_client
    create_access_token! if access_token_expired?

    Octokit::Client.new(access_token: access_token.token)
  end

  def access_token
    access_tokens.last
  end

  def access_token_expired?
    access_token.nil? || access_token.expired?
  end

  def create_access_token!
    token = github_app.api_client.create_app_installation_access_token(installation_id)
    access_tokens.create!(token: token.token, expires_at: token.expires_at)
  end
end
