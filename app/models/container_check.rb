class ContainerCheck < ApplicationRecord
  belongs_to :account, default: -> { container.account }

  belongs_to :container
end
