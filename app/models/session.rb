class Session < ApplicationRecord
  has_secure_token length: 32

  DEFAULT_SESSION_DURATION = 1.month

  belongs_to :user

  attribute :expires_at, :datetime, default: -> { DEFAULT_SESSION_DURATION.from_now }

  scope :active, -> { where(expires_at: Time.current..) }

  validates :expires_at, presence: true
  validates :token, presence: true, uniqueness: true

  def active?
    expires_at > Time.current
  end

  def expired?
    !active?
  end

  def self.find_by_active_token(token)
    active.find_by(token: token)
  end
end
