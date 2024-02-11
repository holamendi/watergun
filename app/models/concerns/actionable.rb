module Actionable
  extend ActiveSupport::Concern

  included do
    has_many :actions, as: :actionable, dependent: :destroy
    has_one :current_action, -> { where(status: [:pending, :running]) }, class_name: "Action", as: :actionable, dependent: :destroy
  end

  def enqueue_action!(action_type)
    actions.create!(action_type:, org:, server:).perform_later
  end
end
