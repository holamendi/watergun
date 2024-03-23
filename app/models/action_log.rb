class ActionLog < ApplicationRecord
  include BelongsToOrg

  attribute :ssh_commands, Ssh::Command.to_array_type

  belongs_to :action

  def text_output
    ssh_commands.map(&:text_output).join
  end
end
