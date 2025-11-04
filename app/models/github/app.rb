class Github::App < ApplicationRecord
  belongs_to :account

  has_many :github_installations, class_name: "Github::Installation", foreign_key: :github_app_id, dependent: :destroy

  def new_installation_url
    "#{html_url}/installations/new"
  end

  def api_client
    Octokit::Client.new(bearer_token:)
  end

  private

  def bearer_token
    payload = {
      iat: Time.now.to_i - 60,
      exp: Time.now.to_i + (10 * 60),
      iss: client_id
    }

    JWT.encode(payload, private_key, "RS256")
  end

  def private_key
    OpenSSL::PKey::RSA.new(pem)
  end
end
