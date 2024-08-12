class Github::Event < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :github_integration, class_name: "Github::Integration", inverse_of: :github_events

  scope :processed, -> { where.not(processed_at: nil) }

  def processed?
    processed_at.present?
  end

  def event
    headers["HTTP_X_GITHUB_EVENT"]
  end

  def action
    payload["action"]
  end

  def slug
    [event, action].compact.join(".")
  end
end
