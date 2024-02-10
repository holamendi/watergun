module Actionable
  extend ActiveSupport::Concern

  included do
    has_many :actions, as: :actionable, dependent: :destroy
    has_one :current_action, -> { where(status: [:pending, :running]) }, class_name: "Action", as: :actionable, dependent: :destroy
  end

  def create_server_event!(event_type)
    server_events.create!(event_type:, org:, server:)
  end
end
