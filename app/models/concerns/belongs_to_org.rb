module BelongsToOrg
  extend ActiveSupport::Concern

  included do
    belongs_to :org

    after_initialize -> { self.org ||= Current.org }, if: :new_record?
  end
end
