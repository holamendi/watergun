module BelongsToServer
  extend ActiveSupport::Concern

  included do
    belongs_to :server

    after_initialize -> { self.server ||= Current.server }, if: :new_record?
  end
end
