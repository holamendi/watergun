# == Schema Information
#
# Table name: server_identities
#
#  id              :integer          not null, primary key
#  ssh_private_key :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  org_id          :integer          not null
#  server_id       :integer          not null
#
# Indexes
#
#  index_server_identities_on_id_and_server_id  (id,server_id) UNIQUE
#  index_server_identities_on_org_id            (org_id)
#  index_server_identities_on_server_id         (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
class ServerIdentity < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  attribute :ssh_private_key, default: -> { SSHKey.generate.private_key }

  validates :ssh_private_key, presence: true, uniqueness: true

  def public_key
    @public_key ||= SSHKey.new(ssh_private_key).ssh_public_key
  end
end
