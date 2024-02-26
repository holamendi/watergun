module Actionable
  extend ActiveSupport::Concern

  included do
    has_many :actions, as: :actionable, dependent: :destroy
    has_one :current_action, -> { pending_or_running }, class_name: "Action", as: :actionable, dependent: :destroy
  end

  def enqueue_action!(action_type, attributes = {})
    action_class(action_type).create!(actionable: self, **attributes).enqueue
  end

  def action_class(action_type)
    "Actions::#{self.class.name.pluralize}::#{action_type.to_s.classify}".constantize
  end
end
