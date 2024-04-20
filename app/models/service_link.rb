class ServiceLink < ApplicationRecord
  include BelongsToOrg
  include Discard::Model

  belongs_to :app, touch: true
  belongs_to :service

  enum status: {
    pending: "pending",
    linked: "linked"
  }, _default: "pending"

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}
end
