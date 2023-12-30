# == Schema Information
#
# Table name: dokku_users
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
#  index_dokku_users_on_id_and_server_id  (id,server_id) UNIQUE
#  index_dokku_users_on_org_id            (org_id)
#  index_dokku_users_on_server_id         (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
require 'rails_helper'

RSpec.describe Dokku::User, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
