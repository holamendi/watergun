# == Schema Information
#
# Table name: container_metrics
#
#  id                :integer          not null, primary key
#  block_io          :string           not null
#  cpu_percentage    :float            not null
#  memory_percentage :float            not null
#  memory_usage      :string           not null
#  network_io        :string           not null
#  timestamp         :datetime         not null
#  container_id      :integer          not null
#  org_id            :integer          not null
#
# Indexes
#
#  index_container_metrics_on_container_id  (container_id)
#  index_container_metrics_on_org_id        (org_id)
#  index_container_metrics_on_timestamp     (timestamp)
#
# Foreign Keys
#
#  container_id  (container_id => containers.id)
#  org_id        (org_id => orgs.id)
#
require "test_helper"

class ContainerMetricTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
