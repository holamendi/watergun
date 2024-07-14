class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true
  belongs_to :service, touch: true

  str_enum :status, [:pending, :active, :deleting, :deleted, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}
end
