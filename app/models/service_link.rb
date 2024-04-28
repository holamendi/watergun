class ServiceLink < ApplicationRecord
  include BelongsToOrg
  include Discard::Model

  belongs_to :app, touch: true
  belongs_to :service

  enum status: {
    pending: "pending",
    linked: "linked",
    unlinked: "unlinked"
  }, _default: "pending"

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  def linked!(at = Time.current)
    update!(status: :linked, linked_at: at)
  end

  def unlinked!(at = Time.current)
    update!(status: :unlinked, unlinked_at: at)
  end
end
