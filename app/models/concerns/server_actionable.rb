module ServerActionable
  extend ActiveSupport::Concern

  included do
    has_many :server_action_runs, as: :target, dependent: :nullify
    has_one :server_action_run, -> { recent }, as: :target
  end
end
