class ServerEvent < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  belongs_to :eventable, polymorphic: true, optional: true
  belongs_to :membership, optional: true

  has_one :server_event_log, dependent: :destroy

  enum status: {
    running: "running",
    success: "success",
    failure: "failure"
  }, _prefix: true

  enum event_type: {
    app_create: "app_create",
    app_destroy: "app_destroy",
    server_create: "server_create",
    server_provision: "server_provision"
  }, _prefix: true
end
