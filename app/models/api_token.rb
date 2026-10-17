class ApiToken < ApplicationRecord
  SCOPES = %w[apps:read apps:write deployments:write env:write operations:read logs:read].freeze

  belongs_to :account
  belongs_to :user, optional: true
  has_many :audits, class_name: "ApiTokenAudit", dependent: :destroy

  attr_reader :token

  before_validation :generate_secret, if: :new_record?

  attribute :read_only, :boolean, default: false
  attribute :expires_at, :datetime, default: -> { 1.year.from_now }

  validates :token_digest, :expires_at, presence: true
  validates :read_only, inclusion: {in: [true, false]}
  validate :valid_scopes
  validate :owner_membership
  validates :user, presence: true, on: :issue
  validates :name, presence: true, length: {maximum: 100}, on: :issue
  validate :issuance_expiry, on: :issue

  def public_metadata
    {
      id: id, name: name, scopes: scopes, read_only: read_only,
      created_at: created_at&.utc&.iso8601, expires_at: expires_at&.utc&.iso8601,
      revoked_at: revoked_at&.utc&.iso8601, last_used_at: last_used_at&.utc&.iso8601
    }
  end

  def permits?(scope)
    scopes.is_a?(Array) && scopes.include?(scope)
  end

  def self.authenticate(secret)
    fingerprint = digest(secret)
    return unless fingerprint
    token = where(revoked_at: nil).where("expires_at > ?", Time.current).find_by(token_digest: fingerprint)
    return if token&.user_id && !Membership.exists?(user_id: token.user_id, account_id: token.account_id)
    token
  end

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret) if secret.is_a?(String) && !secret.empty? && secret.bytesize <= 8192
  end

  def serializable_hash(options = nil)
    super.except("token_digest")
  end

  private

  def owner_membership
    errors.add(:user, :invalid) if user && !Membership.exists?(user: user, account: account)
  end

  def issuance_expiry
    errors.add(:expires_at, :invalid) unless expires_at && expires_at > Time.current && expires_at <= 1.year.from_now
  end

  def valid_scopes
    errors.add(:scopes, :invalid) unless scopes.is_a?(Array) && scopes.all? { |scope| SCOPES.include?(scope) } && scopes.uniq == scopes
  end

  def generate_secret
    return if token_digest.present?
    @token = "wg_#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = Digest::SHA256.hexdigest(@token)
  end
end
