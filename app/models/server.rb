# == Schema Information
#
# Table name: servers
#
#  id             :integer          not null, primary key
#  cpu_type       :string
#  data           :json
#  dokku_token    :string           not null
#  last_synced_at :datetime
#  name           :string           not null
#  provider       :string           not null
#  public_ip      :string
#  status         :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  org_id         :integer          not null
#
# Indexes
#
#  index_servers_on_dokku_token     (dokku_token) UNIQUE
#  index_servers_on_last_synced_at  (last_synced_at)
#  index_servers_on_org_id          (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
class Server < ApplicationRecord
  include BelongsToOrg
  has_secure_token :dokku_token, length: 32

  USER = "watergun"

  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  enum provider: {
    digitalocean: "digitalocean",
    hetzner: "hetzner"
  }, _prefix: true

  enum status: {
    active: "active"
  }, _prefix: true, _default: "active"

  has_one :server_identity, dependent: :destroy

  has_many :apps
  has_many :containers, dependent: :destroy
  has_many :actions, dependent: :destroy
  has_many :services, dependent: :destroy

  after_create :create_server_identity

  delegate :ssh_private_key, to: :server_identity

  def ssh_session(&block)
    Ssh::Session.new(server: self).connect(&block)
  end

  def available_dokku_builders
    if cpu_type.include?("x86")
      DOKKU_BUILDERS
    else
      DOKKU_BUILDERS.except("herokuish")
    end
  end
end
