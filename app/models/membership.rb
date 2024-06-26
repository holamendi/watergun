class Membership < ApplicationRecord
  belongs_to :account, default: -> { Current.account}

  belongs_to :user
end
