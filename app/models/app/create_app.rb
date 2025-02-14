class App::CreateApp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project
  attribute :name
  attribute :repo
  attribute :branch
  attribute :webhook_deploy, :boolean, default: false

  attribute :app

  validates :project, :repo, :branch, presence: true
  validates :webhook_deploy, inclusion: {in: [true, false]}
  validate :validate_remote_repo_exists, if: -> { repo.present? }
  validate :validate_remote_branch_exists, if: -> { branch.present? }

  def save
    return false unless valid?

    ApplicationRecord.transaction do
      create_app!
      create_github_repo!
      ServerActions::CreateApp.run_later!(project.server, app)
    end

    true
  end

  private

  def create_app!
    self.app = project.apps.create!(
      server: project.server,
      name: app_name
    )
  end

  def create_github_repo!
    app.create_github_repo!(
      account: project.account,
      repo:,
      branch:,
      webhook_deploy:,
      private: remote_repo.private?
    )
  end

  def account
    project.account
  end

  def github_api_client
    account.github_integration.api_client
  end

  def remote_repo
    @remote_repo ||= github_api_client.repo(repo)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def remote_branch
    @remote_branch ||= github_api_client.branch(repo, branch)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def app_name
    name.presence || default_app_name
  end

  def default_app_name
    repo.split("/").last
  end

  def validate_remote_repo_exists
    errors.add(:repo, "does not exist") unless remote_repo
  end

  def validate_remote_branch_exists
    errors.add(:branch, "does not exist") unless remote_branch
  end
end
