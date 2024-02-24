module Actionable
  extend ActiveSupport::Concern

  included do
    has_many :actions, as: :actionable, dependent: :destroy
    has_one :current_action, -> { pending_or_running }, class_name: "Action", as: :actionable, dependent: :destroy
  end

  def create_and_enqueue_action!(action_type, payload = {})
    actions.create!(org:, server:, action_type:, payload:).enqueue!
  end

  def create_and_enqueue_actions!(actions)
    Action.transaction do
      actions.each do |action|
        action_type, payload = action
        create_and_enqueue_action!(action_type, payload)
      end
    end
  end
end
