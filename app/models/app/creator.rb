class App::Creator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Memery

  attribute :project
  attribute :name
  attribute :repo
  attribute :branch
  attribute :webhook_deploy, default: false
  attribute :app

  validates :project, presence: true
  validates :repo, presence: true
  validates :branch, presence: true
  validates :webhook_deploy, inclusion: {in: [true, false]}
  validate :validate_remote_repo_exists, if: -> { repo.present? }
  validate :validate_remote_branch_exists, if: -> { branch.present? }

  def create
    return false unless valid?

    ApplicationRecord.transaction do
      self.app = project.apps.create!(name: app_name)
      app.create_github_repo!(repo:, branch:, webhook_deploy:, private: remote_repo.private?)
      ServerAction::CreateApp.run_later!(app)
    end
    true
  end

  private

  def github_api_client
    Current.account.github_integration.api_client
  end

  memoize def remote_repo
    github_api_client.repo(repo)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  memoize def remote_branch
    github_api_client.branch(repo, branch)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def app_name
    name.presence || repo_name
  end

  def repo_name
    repo.split("/").last
  end

  def validate_remote_repo_exists
    errors.add(:repo, "does not exist") unless remote_repo
  end

  def validate_remote_branch_exists
    errors.add(:branch, "does not exist") unless remote_branch
  end
end
