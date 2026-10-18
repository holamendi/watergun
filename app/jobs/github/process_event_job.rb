class Github::ProcessEventJob < ApplicationJob
  queue_as :default

  def perform(github_event)
    @github_event = github_event
    return if @github_event.processed?

    @github_installation = @github_event.installation
    @account = github_event.account

    case github_event.slug
    when "push"
      Current.set(user: nil, api_token: nil, account: @account, source: :web) { create_deployments! }
      return
    when "installation.created"
      # No-op for now
    when "installation.deleted"
      github_event.update_column(:processed_at, Time.current)
      @github_installation.destroy
      return
    end

    github_event.touch(:processed_at)
  end

  def self.recover_pending
    Github::Event.where(processed_at: nil).where.not(pending_app_ids: nil).find_each do |event|
      perform_later(event)
    rescue => error
      ServerAction::Runner.report(error, nil, phase: "webhook recovery dispatch")
    end
  end

  private

  def create_deployments!
    @github_event.with_lock do
      return if @github_event.processed?
      if @github_event.pending_app_ids.nil?
        @github_event.update!(pending_app_ids: matching_repos.pluck(:app_id))
      end
      @github_event.update!(processed_at: Time.current) if @github_event.pending_app_ids.empty?
    end

    @github_event.pending_app_ids.each do |app_id|
      app = @account.apps.kept.find_by(id: app_id)
      unless app && matching_repos.exists?(app_id: app_id)
        @github_event.with_lock { settle_target!(app_id) }
        next
      end
      # Resolve the immutable commit outside event/app/token row locks. Each
      # target commits independently, so a busy app cannot drop the other work.
      command = Deployment::CreateDeployment.new(app: app, commit_sha: @github_event.payload["after"], github_event: @github_event)
      raise ActiveModel::ValidationError, command unless command.prepare

      begin
        @github_event.with_lock do
          next unless @github_event.pending_app_ids.include?(app_id)
          # Retained linkage identifies an already accepted target on redelivery.
          command.save! unless @github_event.deployments.exists?(app_id: app_id)
          settle_target!(app_id)
        end
      rescue ServerAction::Conflict::Error
        # The retained event/target is the durable deferral, not this job retry.
        next
      rescue => error
        # A post-commit dispatch/notification exception must not reaccept work.
        run = ServerActionRun.find_by(id: command.server_action_run&.id)
        raise unless run && @github_event.reload.deployments.exists?(app_id: app_id)

        ServerAction::Runner.report(error, run.id, phase: "webhook accepted dispatch")
      end
    end
    defer_remaining! unless @github_event.reload.processed?
  end

  def matching_repos
    ref = @github_event.payload["ref"]
    return @account.github_repos.none if @github_event.payload["deleted"] || !ref.is_a?(String) || !ref.start_with?("refs/heads/")

    @account.github_repos.joins(:app).merge(App.kept).where(repo: @github_event.payload.dig("repository", "full_name"),
      branch: ref.delete_prefix("refs/heads/"), webhook_deploy: true)
  end

  def settle_target!(app_id)
    pending = @github_event.pending_app_ids - [app_id]
    @github_event.update!(pending_app_ids: pending, processed_at: pending.empty? ? Time.current : nil)
  end

  def defer_remaining!
    self.class.set(wait: 30.seconds).perform_later(@github_event)
  rescue => error
    ServerAction::Runner.report(error, nil, phase: "webhook retry dispatch")
  end
end
