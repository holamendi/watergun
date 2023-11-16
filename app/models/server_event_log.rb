class ServerEventLog < ApplicationRecord
  include BelongsToOrg

  belongs_to :server_event
end
