# == Schema Information
#
# Table name: services
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  name         :string           not null
#  service_type :string           not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  dokku_id     :string
#  org_id       :integer          not null
#  server_id    :integer          not null
#
# Indexes
#
#  index_services_on_org_id     (org_id)
#  index_services_on_server_id  (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
class Service < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer
  include Discard::Model
  include DokkuEntity
  include ServerEventable

  SERVER_EVENT_TYPES = %w[
    create
    destroy
    restart
  ].freeze

  enum service_type: {
    postgres: "postgres",
    redis: "redis"
  }, _prefix: true

  after_create_commit -> { create_server_event!("create") }
  after_discard -> { create_server_event!("destroy") }
  after_update_commit -> { broadcast_replace_to self, :header, target: [self, :header], partial: "services/header", locals: {service: self} }

  def restart!
    create_server_event!("restart")
  end
end
