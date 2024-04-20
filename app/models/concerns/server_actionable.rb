module ServerActionable
  extend ActiveSupport::Concern

  included do
    has_many :server_actions, as: :actionable, dependent: :destroy
    has_one :current_server_action, -> { pending_or_running }, class_name: "ServerAction", as: :actionable, dependent: :destroy
  end
end
