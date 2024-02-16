# == Schema Information
#
# Table name: environment_configurations
#
#  id                            :integer          not null, primary key
#  environment_configurable_type :string           not null
#  variables                     :json
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  environment_configurable_id   :integer          not null
#  org_id                        :integer          not null
#
# Indexes
#
#  index_environment_configurations_on_environment_configurable  (environment_configurable_type,environment_configurable_id)
#  index_environment_configurations_on_org_id                    (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
require "test_helper"

class EnvironmentConfigurationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
