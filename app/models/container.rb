class Container < ApplicationRecord
  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }

  belongs_to :containerizable, polymorphic: true
  has_many :checks, class_name: "ContainerCheck", dependent: :delete_all

  enum status: enum_keys(
    :running,
    :stopped
  ), _default: :running
end
