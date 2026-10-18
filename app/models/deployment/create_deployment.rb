class Deployment::CreateDeployment
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :app
  attribute :commit_sha
  attribute :github_event
  attribute :builder

  attr_reader :server_action_run

  validates :app, presence: true
  validate :validate_prerequisites
  validate :validate_commit_sha, if: -> { errors.empty? }

  def prepare
    identity = source_identity
    return false unless valid?

    @prepared_source = identity
    true
  end

  def save!(enqueue: true)
    raise ActiveModel::ValidationError, self unless @prepared_source || prepare

    ServerAction::Conflict.with_app_lock(app) do |locked_app|
      self.app = locked_app
      raise ServerAction::Conflict::Error unless source_identity == @prepared_source
      ServerAction::TargetValidation.app_context!(app)
      attributes = deployment_attributes
      attributes[:source] = :github_webhook if github_event
      deployment = app.deployments.create!(github_event:, **attributes)
      selected_builder = builder || app.builder
      @server_action_run = ServerAction::Enqueue.build(action: "apps.deploy", target: deployment, payload: selected_builder ? {builder: selected_builder} : {})
      ServerAction::Enqueue.persist(server_action_run) if enqueue
      deployment
    end
  end

  private

  def source_identity
    return unless app

    repository = app.github_repo
    {server_id: app.server_id, installation_id: app.account.github_installation&.id,
     repository_id: repository&.id, repo: repository&.repo, branch: repository&.branch,
     builder: app.builder, selected_builder: builder, commit_sha: commit_sha}
  end

  def validate_prerequisites
    return unless app

    ServerAction::TargetValidation.app_context!(app)
    repository = app.github_repo
    if !repository || repository.repo.blank? || repository.branch.blank?
      errors.add(:base, "GitHub repository is required")
    elsif repository.account_id != app.account_id
      errors.add(:base, "GitHub repository ownership mismatch")
    end
    errors.add(:base, "GitHub installation is required") unless app.account.github_installation
  end

  def remote_commit
    @remote_commit ||= if commit_sha.present?
      github_api_client.commit(app.github_repo.repo, commit_sha)
    else
      github_api_client.branch(app.github_repo.repo, app.github_repo.branch).commit
    end
  rescue Octokit::UnprocessableEntity, Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def deployment_attributes
    {
      sha: remote_commit.sha,
      author_login: remote_commit.author&.login,
      author_url: remote_commit.author&.html_url,
      author_avatar_url: remote_commit.author&.avatar_url,
      author_date: remote_commit.commit.author&.date,
      commit_message: remote_commit.commit.message,
      commit_html_url: remote_commit.html_url
    }
  end

  def github_api_client
    @github_api_client ||= app.account.github_installation.api_client
  end

  def validate_commit_sha
    return if remote_commit.present? && remote_commit.sha.is_a?(String) && remote_commit.sha.match?(/\A[0-9a-fA-F]{40}\z/)

    errors.add(:commit_sha, "does not exist")
  end
end
