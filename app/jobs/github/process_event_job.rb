class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    return unless github_event.push_event?

    github_repo = github_event.github_repo
    return unless github_repo.webhook_deploy? && github_repo.branch == github_event.push_branch

    app = github_repo.app
    commit_sha = github_event.payload["after"]

    Current.set(account: app.account, server: app.server) do
      Deployment::Creator.new(app:, commit_sha:).create!
    end
  end
end
