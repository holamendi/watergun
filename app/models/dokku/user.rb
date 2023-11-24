module Dokku
  class User < ApplicationRecord
    include BelongsToOrg
    include BelongsToServer

    self.table_name = "dokku_users"

    attribute :ssh_private_key, default: -> { SSHKey.generate.private_key }

    validates :ssh_private_key, presence: true, uniqueness: true

    def public_key
      @public_key ||= SSHKey.new(ssh_private_key).ssh_public_key
    end
  end
end
