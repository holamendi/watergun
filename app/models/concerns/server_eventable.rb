module ServerEventable
  extend ActiveSupport::Concern

  included do
    has_many :server_events, as: :eventable, dependent: :destroy
    has_one :running_server_event, -> { status_running }, class_name: "ServerEvent", as: :eventable, dependent: :destroy
  end
end
