class ApiToken < ApplicationRecord
  has_secure_token

  belongs_to :account

  attribute :read_only, :boolean, default: false
  attribute :expires_at, :datetime, default: -> { 1.year.from_now }

  scope :active, -> { where(expires_at: Time.current..) }

  validates :token, :expires_at, presence: true
end
