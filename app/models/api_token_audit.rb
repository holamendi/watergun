class ApiTokenAudit < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :api_token

  validates :action, inclusion: {in: %w[issued revoked rotated claimed]}
  validates :request_id, presence: true, length: {maximum: 128}
end
