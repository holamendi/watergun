class Server < ApplicationRecord
  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  belongs_to :account, default: -> { Current.account }

  has_one :ssh_key, dependent: :destroy

  has_many :apps, dependent: :destroy
  has_many :containers, dependent: :destroy
  has_many :actions, class_name: "ServerAction", dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :services, dependent: :destroy

  str_enum :status, %i[pending active deleting deleted error], default: :pending

  after_create { create_ssh_key!(account:) }

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
      Array.wrap(commands).each do |command|
        ssh.execute(command)
      end
    end
  end

  def available_dokku_builders
    return DOKKU_BUILDERS if cpu_type.include?("x86")

    DOKKU_BUILDERS.except("herokuish")
  end
end
