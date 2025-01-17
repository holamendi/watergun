module Server::SshSessionable
  extend ActiveSupport::Concern

  def ssh_session(&)
    attempts = 0
    Ssh::Session.new(server: self).connect(&)
  rescue Net::SSH::ConnectionTimeout
    attempts += 1
    retry if attempts < 4
    raise
  end

  def execute_ssh_commands(commands)
    return if commands.blank?

    ssh_session do |ssh|
      Array(commands).each do |command|
        ssh.execute(command)
      end
    end
  end
end
