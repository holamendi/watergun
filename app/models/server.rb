class Server < ApplicationRecord
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

  belongs_to :org

  has_one :dokku_user, class_name: "Dokku::User", dependent: :destroy

  has_many :apps
  has_many :dokku_events, class_name: "Dokku::Event", dependent: :destroy

  store_attribute :data, :public_ip, :string

  after_create -> { create_dokku_user!(org:) }

  def ssh_command!(command)
    Net::SSH.start(public_ip, "watergun", key_data: [dokku_user.private_key], keys_only: true, non_interactive: true) do |ssh|
      ssh.exec!(command)
    end
  end
end
