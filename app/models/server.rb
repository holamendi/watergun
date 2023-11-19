class Server < ApplicationRecord
  include BelongsToOrg

  has_secure_token :dokku_token, length: 32

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

  has_one :dokku_user, class_name: "Dokku::User", dependent: :destroy

  has_many :apps
  has_many :server_events, dependent: :destroy

  store_attribute :data, :public_ip, :string
end
