module BelongsToMembership
  extend ActiveSupport::Concern

  included do
    belongs_to :membership

    after_initialize -> { self.membership ||= Current.membership }, if: :new_record?
  end
end
