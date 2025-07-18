class Deployment::CreateDeployment
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :app
  attribute :commit_sha
  attribute :github_event

  validates :app, presence: true
  validate :validate_commit_sha, if: -> { commit_sha.present? }

  def save!
    validate!

    deployment = app.deployments.create!(deployment_attributes)
    ServerActions::DeployApp.run_later!(app.server, deployment)
    deployment
  end

  private

  def remote_commit
    @remote_commit ||= if commit_sha.present?
      github_api_client.commit(app.github_repo.repo, commit_sha)
    else
      github_api_client.branch(app.github_repo.repo, app.github_repo.branch).commit
    end
  rescue Octokit::UnprocessableEntity
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
    app.github_app.installations.first&.api_client
  end

  def validate_commit_sha
    return if remote_commit.present?

    errors.add(:commit_sha, "does not exist")
  end
end
