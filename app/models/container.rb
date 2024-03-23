class Container < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  belongs_to :containerizable, polymorphic: true
  has_many :container_metrics, dependent: :delete_all

  enum status: {
    running: "running",
    stopped: "stopped"
  }, _default: "running"
end
