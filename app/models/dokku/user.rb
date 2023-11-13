class Dokku::User < ApplicationRecord
  belongs_to :org
  belongs_to :server

  attribute :private_key, default: -> { SSHKey.generate.private_key }

  validates :private_key, presence: true, uniqueness: true
end
