class Membership < ApplicationRecord
  belongs_to :org, default: -> { Current.org }

  belongs_to :user
end
