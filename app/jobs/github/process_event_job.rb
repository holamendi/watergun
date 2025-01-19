class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    @github_event = github_event
    @github_integration = github_event.github_integration
    @account = github_event.account

    case github_event.slug
    when "push"
      create_deployments!
    when "installation.created"
      @github_integration.install!(
        installation_id: @github_event.payload.dig("installation", "id"),
        account_login: @github_event.payload.dig("installation", "account", "login")
      )
    when "installation.deleted"
      @github_integration.uninstall!
    end

    github_event.touch(:processed_at)
  end

  private

  def create_deployments!
    repo = @github_event.payload.dig("repository", "full_name")
    branch = @github_event.payload["ref"].split("/").last
    commit_sha = @github_event.payload["after"]

    @account.github_repos.kept.where(repo:, branch:, webhook_deploy: true).each do |github_repo|
      Deployment::CreateDeployment.new(app: github_repo.app, commit_sha:).save
    end
  end
end
