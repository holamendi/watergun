class Server < ApplicationRecord
  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  belongs_to :account

  has_one :ssh_key, dependent: :destroy

  has_many :apps, dependent: :destroy
  has_many :checks, class_name: "ServerCheck", dependent: :delete_all
  has_many :containers, dependent: :destroy
  has_many :actions, class_name: "ServerAction", dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :services, dependent: :destroy

  enum :status, Enum[:pending, :active, :deleted, :error], default: :pending
  enum :cpu_type, Enum[:x86, :arm64], default: :x86

  after_create :create_ssh_key!

  def available_dokku_builders
    return DOKKU_BUILDERS if cpu_type.include?("x86")

    DOKKU_BUILDERS.except("herokuish")
  end

  def ssh_session
    connection_attempts = 0
    connection_established = false

    begin
      Ssh::Session.new(
        host: public_ip,
        user: SshKey::USER,
        private_key: ssh_key.private_key,
        port: ssh_port
      ).connect do |session|
        connection_established = true
        yield(session)
      end
    rescue Net::SSH::ConnectionTimeout
      connection_attempts += 1
      retry if !connection_established && connection_attempts < 4
      raise
    end
  end

  def execute_ssh_commands(commands)
    return if commands.blank?

    ssh_session do |ssh|
      Array(commands).each { ssh.execute(it) }
    end
  end
end
