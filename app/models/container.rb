class Container < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }

  belongs_to :containerizable, polymorphic: true
  has_many :checks, class_name: "ContainerCheck", dependent: :delete_all

  scope :checked_within, ->(from:, to: Time.current) { joins(:checks).where(container_checks: {timestamp: from..to}) }

  str_enum :status, [:running, :stopped], default: :running
end
