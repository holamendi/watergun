module ServerActionable
  extend ActiveSupport::Concern

  included do
    has_many :server_actions, as: :actionable, dependent: :nullify
    has_one :server_action, -> { recent }, as: :actionable, dependent: :destroy
  end
end
