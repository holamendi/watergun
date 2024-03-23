class ServiceLink < ApplicationRecord
  include BelongsToOrg
  include Discard::Model

  belongs_to :app, touch: true
  belongs_to :service

  enum status: {
    pending: "pending",
    linked: "linked"
  }, _prefix: true, _default: "pending"

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  after_create_commit -> { service.enqueue_action!(:link, service_link_id: id, app_dokku_id: app.dokku_id, service_dokku_id: service.dokku_id, service_type: service.service_type) }
  after_discard -> { service.enqueue_action!(:unlink, service_link_id: id, app_dokku_id: app.dokku_id, service_dokku_id: service.dokku_id, service_type: service.service_type) }
end
