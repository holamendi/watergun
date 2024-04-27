class ApiToken < ApplicationRecord
  include BelongsToOrg

  has_secure_token

  belongs_to :user

  attribute :read_only, :boolean, default: false

  validates :token, :expires_at, presence: true
end
