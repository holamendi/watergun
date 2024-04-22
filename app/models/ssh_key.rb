class SshKey < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  USER = "watergun"

  validates :private_key, presence: true

  before_validation on: :create do
    self.private_key = SSHKey.generate.private_key
  end

  def public_key
    @public_key ||= SSHKey.new(private_key).ssh_public_key
  end
end
