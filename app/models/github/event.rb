class Github::Event < ApplicationRecord
  belongs_to :account, default: -> { github_installation.account }
  belongs_to :github_installation, class_name: "Github::Installation", inverse_of: :github_events

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
