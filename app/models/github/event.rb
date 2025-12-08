class Github::Event < ApplicationRecord
  belongs_to :account, default: -> { installation.account }
  belongs_to :installation, class_name: "Github::Installation", foreign_key: :github_installation_id, inverse_of: :events

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
