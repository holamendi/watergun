module Dokku
  class User < ApplicationRecord
    include BelongsToOrg
    include BelongsToServer

    self.table_name = "dokku_users"

    attribute :ssh_private_key, default: -> { SSHKey.generate.private_key }

    validates :ssh_private_key, presence: true, uniqueness: true
  end
end
