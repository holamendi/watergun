class Github::InstallationAccessToken < ApplicationRecord
  belongs_to :account, default: -> { installation.account }
  belongs_to :installation, class_name: "Github::Installation", foreign_key: :github_installation_id, inverse_of: :access_tokens

  def expired?
    expires_at < Time.now
  end
end
