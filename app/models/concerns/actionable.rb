module Actionable
  extend ActiveSupport::Concern

  included do
    has_many :actions, as: :actionable, dependent: :destroy
    has_one :current_action, -> { pending_or_running }, class_name: "Action", as: :actionable, dependent: :destroy
  end

  def enqueue_action!(action_class, attributes = {})
    action_class.create!(actionable: self, **attributes).enqueue
  end
end
