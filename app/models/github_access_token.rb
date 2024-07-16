class GithubAccessToken < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  validates :token, presence: true
  validate :validate_token_scope

  def obfuscated_token
    return nil unless token.present?

    "#{token.first(6)}#{"*" * (token.length - 6)}"
  end

  private

  def validate_token_scope
    return if errors.where(:token).any?
    return if Octokit::Client.new(access_token: token).scopes.include?("repo")

    errors.add(:token, "needs the 'repo' scope")
  rescue Octokit::Unauthorized
    errors.add(:token, "is invalid")
  end
end
