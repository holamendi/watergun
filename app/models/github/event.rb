class Github::Event < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :github_hook, class_name: "Github::Hook", inverse_of: :github_events

  delegate :github_repo, to: :github_hook

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
