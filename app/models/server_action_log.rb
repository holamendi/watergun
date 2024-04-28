class ServerActionLog < ApplicationRecord
  include BelongsToOrg

  attribute :ssh_commands, Ssh::Command.to_array_type

  belongs_to :server_action

  before_validation on: :create do
    self.org = server_action.org
  end

  def text_output
    ssh_commands.map(&:text_output).join
  end
end
