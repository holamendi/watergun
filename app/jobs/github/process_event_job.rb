class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    @github_event = github_event
    return if @github_event.processed?

    @github_installation = @github_event.installation
    @account = github_event.account

    case github_event.slug
    when "push"
      create_deployments!
    when "installation.created"
      # No-op for now
    when "installation.deleted"
      github_event.update_column(:processed_at, Time.current)
      @github_installation.destroy
      return
    end

    github_event.touch(:processed_at)
  end

  private

  def create_deployments!
    ref = @github_event.payload["ref"].to_s
    return unless ref.start_with?("refs/heads/")
    return if @github_event.payload["deleted"] == true

    repo = @github_event.payload.dig("repository", "full_name")
    branch = ref.delete_prefix("refs/heads/")
    commit_sha = @github_event.payload["after"]

    @account.github_repos.where(repo:, branch:, webhook_deploy: true).each do |github_repo|
      Deployment::CreateDeployment.new(app: github_repo.app, commit_sha:).save!
    end
  end
end
