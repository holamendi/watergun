class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    return unless github_event.push_event?

    account = github_event.account
    github_repos = account.github_repos.kept.where(
      repo: github_event.payload["repository"]["full_name"],
      branch: github_event.push_branch,
      webhook_deploy: true
    )

    commit_sha = github_event.payload["after"]

    github_repos.each do |github_repo|
      Current.set(account:, server: github_repo.app.server) do
        Deployment::Creator.new(app: github_repo.app, commit_sha:).create!
      end
    end
  end
end
