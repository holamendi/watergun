class Dokku::User < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  attribute :ssh_private_key, default: -> { SSHKey.generate.private_key }

  validates :ssh_private_key, presence: true, uniqueness: true
end
