class Github::Integration < ApplicationRecord
  REQUIRED_SCOPES = %w[repo admin:repo_hook].freeze

  belongs_to :account, default: -> { Current.account }

  validate :validate_token_scopes, if: -> { personal_access_token.present? }

  def obfuscated_token
    return nil unless personal_access_token.present?

    "#{personal_access_token.first(6)}#{"*" * (personal_access_token.length - 6)}"
  end

  memoize def api_client
    Octokit::Client.new(access_token: personal_access_token)
  end

  private

  def validate_token_scopes
    token_scopes = Octokit::Client.new(access_token: personal_access_token).scopes

    REQUIRED_SCOPES.each do |scope|
      next if token_scopes.include?(scope)

      errors.add(:personal_access_token, "needs the '#{scope}' scope")
    end
  rescue Octokit::Unauthorized
    errors.add(:personal_access_token, "is invalid")
  end
end
