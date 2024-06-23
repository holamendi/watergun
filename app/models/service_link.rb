class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :app, touch: true
  belongs_to :service

  str_enum :status, [:pending, :active, :deleting, :deleted, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  after_create_commit -> { ServerActions::LinkService.perform_later!(self) }
  after_discard -> { ServerActions::UnlinkService.perform_later!(self) }
  after_update_commit -> do
    broadcast_refresh_to(app)
    broadcast_refresh_to(service)
  end
end
