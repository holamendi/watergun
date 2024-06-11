class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :app, touch: true
  belongs_to :service

  enum status: {
    pending: 0,
    linked: 1,
    unlinked: 2
  }, _default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  def linked!(at = Time.current)
    update!(status: :linked, linked_at: at)
  end

  def unlinked!(at = Time.current)
    update!(status: :unlinked, unlinked_at: at)
  end
end
