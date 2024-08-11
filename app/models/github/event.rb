class Github::Event < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :github_integration, class_name: "Github::Integration", inverse_of: :github_events

  def event
    headers["HTTP_X_GITHUB_EVENT"]
  end

  def push_event?
    event == "push"
  end

  def after_sha
    payload["after"]
  end

  def push_branch
    payload["ref"].split("/").last if push_event?
  end
end
