# == Schema Information
#
# Table name: apps
#
#  id         :integer          not null, primary key
#  data       :json             not null
#  dokku_name :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  org_id     :integer          not null
#  server_id  :integer          not null
#
# Indexes
#
#  index_apps_on_org_id     (org_id)
#  index_apps_on_server_id  (server_id)
#
# Foreign Keys
#
#  org_id     (org_id => orgs.id)
#  server_id  (server_id => servers.id)
#
require 'rails_helper'

RSpec.describe App, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
