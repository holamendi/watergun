# == Schema Information
#
# Table name: github_access_tokens
#
#  id         :integer          not null, primary key
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  org_id     :integer          not null
#
# Indexes
#
#  index_github_access_tokens_on_org_id  (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
require "test_helper"

class GithubAccessTokenTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
