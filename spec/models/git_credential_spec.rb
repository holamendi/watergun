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
require 'rails_helper'

RSpec.describe GitCredential, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
