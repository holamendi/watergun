class Server < ApplicationRecord
  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  belongs_to :account

  has_one :ssh_key, dependent: :destroy

  has_many :apps, dependent: :destroy
  has_many :containers, dependent: :destroy
  has_many :actions, class_name: "ServerAction", dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :services, dependent: :destroy

  enum :status, %w[pending active deleting deleted error].index_by(&:itself), default: :pending

  after_create :create_ssh_key!

  def available_dokku_builders
    return DOKKU_BUILDERS if cpu_type.include?("x86")

    DOKKU_BUILDERS.except("herokuish")
  end

  def ssh_session(&)
    connection_attempts = 0
    Ssh::Session.new(
      host: public_ip,
      user: SshKey::USER,
      private_key: ssh_key.private_key,
      port: ssh_port
    ).connect(&)
  rescue Net::SSH::ConnectionTimeout
    connection_attempts += 1
    retry if connection_attempts < 4
    raise
  end

  def execute_ssh_commands(commands)
    return if commands.blank?

    ssh_session do |ssh|
      Array(commands).each { ssh.execute(it) }
    end
  end
end
