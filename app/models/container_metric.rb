class ContainerMetric < ApplicationRecord
  belongs_to :org, default: -> { Current.org }

  belongs_to :container
end
