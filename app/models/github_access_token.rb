class GithubAccessToken < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  validates :token, presence: true
  validate :validate_token_scope

  private

  def validate_token_scope
    return if errors.where(:token).any?
    return if Octokit::Client.new(access_token: token).scopes.include?("repo")

    errors.add(:token, "needs the 'repo' scope")
  rescue Octokit::Unauthorized
    errors.add(:token, "is invalid")
  end
end
