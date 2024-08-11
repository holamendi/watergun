class Deployment::Creator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Memery

  attribute :app
  attribute :commit_sha

  validates :app, presence: true

  def create!
    validate!

    deployment = app.deployments.create!(
      sha: remote_commit.sha,
      author_login: remote_commit.author.login,
      author_url: remote_commit.author.html_url,
      author_avatar_url: remote_commit.author.avatar_url,
      author_date: remote_commit.commit.author.date,
      commit_message: remote_commit.commit.message,
      commit_html_url: remote_commit.html_url
    )

    ServerAction::DeployApp.run_later!(deployment)
    deployment
  end

  private

  memoize def remote_commit
    if commit_sha.present?
      github_api_client.commit(app.github_repo.repo, commit_sha)
    else
      github_api_client.branch(app.github_repo.repo, app.github_repo.branch).commit
    end
  end

  def github_api_client
    Current.account.github_integration.api_client
  end
end
