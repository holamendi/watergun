class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { service.account }
  belongs_to :app, touch: true
  belongs_to :service, touch: true
  belongs_to :env_variable

  enum :status, Enum[:pending, :active, :deleting, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  delegate :server, to: :service
end
