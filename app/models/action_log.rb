# == Schema Information
#
# Table name: action_logs
#
#  id           :integer          not null, primary key
#  ssh_commands :json             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  action_id    :integer          not null
#  org_id       :integer          not null
#
# Indexes
#
#  index_action_logs_on_action_id         (action_id)
#  index_action_logs_on_id_and_action_id  (id,action_id) UNIQUE
#  index_action_logs_on_org_id            (org_id)
#
# Foreign Keys
#
#  action_id  (action_id => actions.id)
#  org_id     (org_id => orgs.id)
#
class ActionLog < ApplicationRecord
  include BelongsToOrg

  attribute :ssh_commands, SshCommand.to_array_type

  belongs_to :server_event

  def output
    ssh_commands.map(&:output).join
  end
end
