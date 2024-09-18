class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true
  belongs_to :service, touch: true
  belongs_to :env_variable

  str_enum :status, [:pending, :active, :deleting, :error], default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}
end
