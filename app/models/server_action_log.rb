class ServerActionLog < ApplicationRecord
  include BelongsToOrg

  attribute :ssh_commands, Ssh::Command.to_array_type

  belongs_to :server_action

  def text_output
    ssh_commands.map(&:text_output).join
  end
end
