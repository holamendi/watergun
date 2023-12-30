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
  store_attribute :data, :architecture, :string

  def ssh_command!(command, server_event)
    status = {}
    output = nil

    Net::SSH.start(public_ip, "watergun", key_data: [dokku_user.ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
      output = ""
      ssh.exec!(command, status:) do |channel, stream, data|
        output << data
        Turbo::StreamsChannel.broadcast_append_to server_event.eventable, :server_events, target: "logs_server_event_#{server_event.id}", content: "<p>#{data}</p>"
      end
    end

    [status[:exit_code], output]
  end
end
