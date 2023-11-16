class Membership < ApplicationRecord
  include BelongsToOrg

  belongs_to :user
end
