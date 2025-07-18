class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    @github_event = github_event
    @github_installation = github_event.github_installation
    @account = github_event.account

    case github_event.slug
    when "push"
      create_deployments!
    when "installation.created"
      @github_installation.update!(
        installation_id: @github_event.payload.dig("installation", "id"),
        account_login: @github_event.payload.dig("installation", "account", "login")
      )
    when "installation.deleted"
      @github_installation.update!(
        installation_id: nil,
        account_login: nil,
        access_token: nil,
        expires_at: nil
      )
    end

    github_event.touch(:processed_at)
  end

  private

  def create_deployments!
    repo = @github_event.payload.dig("repository", "full_name")
    branch = @github_event.payload["ref"].split("/").last
    commit_sha = @github_event.payload["after"]

    @account.github_repos.kept.where(repo:, branch:, webhook_deploy: true).each do |github_repo|
      Deployment::CreateDeployment.new(app: github_repo.app, commit_sha:).save!
    end
  end
end
