class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :app, touch: true
  belongs_to :service

  str_enum :status, [:pending, :active, :deleting, :deleted, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}
end
