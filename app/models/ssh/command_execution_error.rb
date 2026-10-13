class Ssh::CommandExecutionError < StandardError
  attr_reader :ssh_command

  def initialize(ssh_command)
    @ssh_command = ssh_command
  end

  def message
    "command failed with status #{ssh_command.exit_code}: #{ssh_command.redacted_cmd}"
  end
end
