class ServerIdentity < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  USER = "watergun"

  attribute :ssh_private_key, default: -> { SSHKey.generate.private_key }

  validates :ssh_private_key, presence: true, uniqueness: true

  def public_key
    @public_key ||= SSHKey.new(ssh_private_key).ssh_public_key
  end
end
