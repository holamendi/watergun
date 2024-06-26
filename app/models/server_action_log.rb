class ServerActionLog < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  attribute :ssh_commands, Ssh::Command.to_array_type

  belongs_to :server_action

  def text_output
    ssh_commands.map(&:text_output).join
  end

  def to_s
    ssh_commands.map(&:to_s).join("\n")
  end
end
