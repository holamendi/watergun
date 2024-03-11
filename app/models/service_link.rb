# == Schema Information
#
# Table name: service_links
#
#  id         :integer          not null, primary key
#  status     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :integer          not null
#  org_id     :integer          not null
#  service_id :integer          not null
#
# Indexes
#
#  index_service_links_on_app_id                 (app_id)
#  index_service_links_on_org_id                 (org_id)
#  index_service_links_on_service_id             (service_id)
#  index_service_links_on_service_id_and_app_id  (service_id,app_id) UNIQUE
#
# Foreign Keys
#
#  app_id      (app_id => apps.id)
#  org_id      (org_id => orgs.id)
#  service_id  (service_id => services.id)
#
class ServiceLink < ApplicationRecord
  include BelongsToOrg
  include Discard::Model

  belongs_to :app
  belongs_to :service

  enum status: {
    pending: "pending",
    linked: "linked"
  }, _prefix: true, _default: "pending"

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}

  after_create_commit -> { service.enqueue_action!(:link, service_link_id: id, app_dokku_id: app.dokku_id, service_dokku_id: service.dokku_id, service_type: service.service_type) }
  after_discard -> { service.enqueue_action!(:unlink, service_link_id: id, app_dokku_id: app.dokku_id, service_dokku_id: service.dokku_id, service_type: service.service_type) }
end
