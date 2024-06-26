class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true
  belongs_to :service, touch: true

  str_enum :status, [:pending, :active, :deleting, :deleted, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  # after_create_commit -> { ServerActions::LinkService.perform_later!(self) }
  # after_discard -> { ServerActions::UnlinkService.perform_later!(self) }, unless: -> { app.discarded? }
end
