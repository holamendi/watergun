# == Schema Information
#
# Table name: server_event_logs
#
#  id              :integer          not null, primary key
#  ssh_commands    :json             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  org_id          :integer          not null
#  server_event_id :integer          not null
#
# Indexes
#
#  index_server_event_logs_on_id_and_server_event_id  (id,server_event_id) UNIQUE
#  index_server_event_logs_on_org_id                  (org_id)
#  index_server_event_logs_on_server_event_id         (server_event_id)
#
# Foreign Keys
#
#  org_id           (org_id => orgs.id)
#  server_event_id  (server_event_id => server_events.id)
#
class ServerEventLog < ApplicationRecord
  include BelongsToOrg

  attribute :ssh_commands, SshCommand.to_array_type

  belongs_to :server_event

  def output
    ssh_commands.map(&:output).join
  end
end
