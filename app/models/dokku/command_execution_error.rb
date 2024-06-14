module Dokku
  class CommandExecutionError < StandardError
    attr_reader :ssh_command

    def initialize(message, ssh_command)
      super(message)
      @ssh_command = ssh_command
    end
  end
end
