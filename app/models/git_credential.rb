# == Schema Information
#
# Table name: git_credentials
#
#  id                    :integer          not null, primary key
#  description           :string
#  personal_access_token :string           not null
#  provider              :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  org_id                :integer          not null
#
# Indexes
#
#  index_git_credentials_on_org_id  (org_id)
#
# Foreign Keys
#
#  org_id  (org_id => orgs.id)
#
class GitCredential < ApplicationRecord
  include BelongsToOrg

  enum provider: {
    github: 0
  }, _prefix: true, _default: "github"

  def repos
    client.repos
  end

  private

  def client
    Octokit::Client.new(access_token: personal_access_token, per_page: 100)
  end
end
