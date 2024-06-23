class ApiToken < ApplicationRecord
  has_secure_token

  belongs_to :org, default: -> { Current.org }

  attribute :read_only, :boolean, default: false
  attribute :expires_at, :datetime, default: -> { 1.year.from_now }

  validates :token, :expires_at, presence: true
end
