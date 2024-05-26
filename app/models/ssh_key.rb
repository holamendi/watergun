class SshKey < ApplicationRecord
  USER = "watergun"

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }

  validates :private_key, presence: true

  attribute :private_key, default: -> { SSHKey.generate.private_key }

  def public_key
    @public_key ||= SSHKey.new(private_key).ssh_public_key
  end
end
