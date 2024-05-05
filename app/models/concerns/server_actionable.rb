module ServerActionable
  extend ActiveSupport::Concern

  included do
    has_many :server_actions, as: :actionable, dependent: :destroy
    has_one :server_action, -> { order(created_at: :desc) }, as: :actionable, dependent: :destroy
    has_one :current_server_action, -> { queued_or_running }, class_name: "ServerAction", as: :actionable, dependent: :destroy
  end
end
