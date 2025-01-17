class SshKey < ApplicationRecord
  USER = "watergun"

  belongs_to :account, default: -> { server.account }
  belongs_to :server

  validates :private_key, presence: true

  attribute :private_key, default: -> { SSHKey.generate.private_key }

  def public_key
    @public_key ||= SSHKey.new(private_key).ssh_public_key
  end
end
