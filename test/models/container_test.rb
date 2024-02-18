# == Schema Information
#
# Table name: containers
#
#  id                   :integer          not null, primary key
#  block_io             :string           not null
#  cid                  :string           not null
#  containerizable_type :string           not null
#  cpu_percentage       :float            not null
#  last_synced_at       :datetime         not null
#  memory_percentage    :float            not null
#  memory_usage         :string           not null
#  name                 :string           not null
#  network_io           :string           not null
#  status               :string           not null
#  stopped_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  containerizable_id   :integer          not null
#  org_id               :integer          not null
#  server_id            :integer          not null
#
# Indexes
#
#  index_containers_on_cid              (cid)
#  index_containers_on_containerizable  (containerizable_type,containerizable_id)
#  index_containers_on_org_id           (org_id)
#  index_containers_on_server_id        (server_id)
#  index_containers_on_status           (status)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
require "test_helper"

class ContainerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
