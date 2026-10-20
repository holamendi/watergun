class ServerActionLog < ApplicationRecord
  belongs_to :account, default: -> { server_action.account }

  belongs_to :server_action

  def text_output
    ssh_commands.map(&:text_output).join
  end

  def to_s
    ssh_commands.join("\n")
  end
end
