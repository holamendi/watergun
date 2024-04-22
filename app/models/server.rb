class Server < ApplicationRecord
  include BelongsToOrg

  DOKKU_BUILDERS = {
    "herokuish" => "Heroku Buildpacks",
    "dockerfile" => "Dockerfile",
    "nixpacks" => "Nixpacks"
  }

  enum status: {
    active: "active"
  }, _prefix: true, _default: "active"

  has_one :ssh_key, dependent: :destroy

  has_many :apps
  has_many :containers, dependent: :destroy
  has_many :actions, dependent: :destroy
  has_many :services, dependent: :destroy

  after_create :create_ssh_key

  def ssh_session(&)
    Ssh::Session.new(server: self).connect(&)
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
