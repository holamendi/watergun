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

  def ssh_command!(commands, server_event)
    output = nil
    commands = Array.wrap(commands)
    result = []
    output = ""

    Net::SSH.start(public_ip, "watergun", key_data: [dokku_user.ssh_private_key], keys_only: true, non_interactive: true) do |ssh|
      commands.each_with_index do |command, index|
        status = {}
        started_at = Time.current

        if index.zero? || result.present? && result.last[:exit_code].zero?
          ssh.exec!(command, status:) do |channel, stream, data|
            output << data
            Turbo::StreamsChannel.broadcast_append_to server_event.eventable, :server_events, target: "logs_server_event_#{server_event.id}", content: "<p>#{data}</p>"
          end

          finished_at = Time.current

          result << {
            command: command,
            exit_code: status[:exit_code],
            started_at: started_at,
            finished_at: finished_at
          }
        end
      end
    end

    {
      success: result.all? { |r| r[:exit_code].zero? },
      details: result,
      output: output
    }
  end
end
