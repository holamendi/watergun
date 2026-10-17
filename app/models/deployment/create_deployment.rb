class Deployment::CreateDeployment
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :app
  attribute :commit_sha
  attribute :github_event

  validates :app, presence: true
  validate :validate_prerequisites
  validate :validate_commit_sha, if: -> { errors.empty? }

  def save!
    validate!

    Deployment.transaction do
      deployment = app.deployments.create!(github_event:, **deployment_attributes)
      ServerAction::Enqueue.call(action: "apps.deploy", target: deployment)
      deployment
    end
  end

  private

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
    return if remote_commit.present?

    errors.add(:commit_sha, "does not exist")
  end
end
