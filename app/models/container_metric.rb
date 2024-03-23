class ContainerMetric < ApplicationRecord
  include BelongsToOrg

  belongs_to :container
end
