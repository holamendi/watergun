class ContainerCheck < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  belongs_to :container
end
