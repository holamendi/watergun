module ServerEventable
  extend ActiveSupport::Concern

  included do
    has_many :server_events, as: :eventable, dependent: :destroy
  end
end
