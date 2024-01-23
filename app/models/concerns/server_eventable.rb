module ServerEventable
  extend ActiveSupport::Concern

  included do
    has_many :server_events, as: :eventable, dependent: :destroy
    has_one :current_server_event, -> { where(status: [:pending, :running]) }, class_name: "ServerEvent", as: :eventable, dependent: :destroy
  end
end
