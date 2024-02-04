# == Schema Information
#
# Table name: servers
#
#  id          :integer          not null, primary key
#  data        :json
#  dokku_token :string           not null
#  name        :string           not null
#  provider    :string           not null
#  status      :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  org_id      :integer          not null
#
# Indexes
#
#  index_servers_on_dokku_token  (dokku_token) UNIQUE
#  index_servers_on_org_id       (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
class Server < ApplicationRecord
  include BelongsToOrg

  USER = "watergun"

  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  has_secure_token :dokku_token, length: 32

  store_attribute :data, :public_ip, :string
  store_attribute :data, :architecture, :string

  enum provider: {
    digitalocean: "digitalocean",
    hetzner: "hetzner"
  }, _prefix: true

  enum status: {
    active: "active",
    deprovisioning: "deprovisioning",
    error: "error",
    provisioning: "provisioning"
  }, _prefix: true, _default: "provisioning"

  has_one :server_identity, dependent: :destroy

  has_many :apps
  has_many :server_events, dependent: :destroy
  has_many :services, dependent: :destroy

  delegate :ssh_private_key, to: :server_identity

  def execute_ssh_commands(commands, &block)
    Servers::ExecuteSshCommands.new(server: self, commands:).call(&block)
  end
end
