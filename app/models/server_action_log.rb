class ServerActionLog < ApplicationRecord
  belongs_to :account, default: -> { server_action.account }

  belongs_to :server_action

  def text_output
    ssh_commands.map { |command| command_output(command) }.join
  end

  def to_s
    ssh_commands.map { |command| command_log(command) }.join("\n\n")
  end

  private

  def command_output(command)
    Array(command["output"]).map { |log| log["data"] }.join
  end

  def command_log(command)
    lines = ["$ #{command["cmd"]}"]
    output = command_output(command).chomp
    lines << output if output.present?
    lines << "Exit code: #{command["exit_code"]}" if command["exit_code"].present? && command["exit_code"] != 0
    lines.join("\n")
  end
end
