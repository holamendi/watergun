class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    return unless github_event.push_event?

    account = github_event.account
    github_repo = github_event.github_repo

    return unless github_repo.webhook_deploy? && github_event.github_repo.branch == github_event.push_branch

    app = github_repo.app
    commit = github_repo.remote_commit(github_event.payload["after"])

    Current.set(account: account, server: app.server) do
      deployment = app.deployments.create!(
        sha: commit.sha,
        author_login: commit.author.login,
        author_url: commit.author.html_url,
        author_avatar_url: commit.author.avatar_url,
        author_date: commit.commit.author.date,
        commit_message: commit.commit.message,
        commit_html_url: commit.html_url
      )
      ServerAction::DeployApp.run_later!(deployment)
    end
  end
end
