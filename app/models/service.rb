# == Schema Information
#
# Table name: services
#
#  id           :integer          not null, primary key
#  data         :json             not null
#  discarded_at :datetime
#  dokku_name   :string           not null
#  name         :string           not null
#  service_type :string           not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
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
  include ServerEventable

  enum service_type: {
    postgres: "postgres",
    redis: "redis"
  }, _prefix: true

  before_validation :set_dokku_name, on: :create

  private

  def set_dokku_name
    self.dokku_name = "wgn-#{name.parameterize}-#{SecureRandom.hex(2)}"
  end
end
