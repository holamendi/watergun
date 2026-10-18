class App::CreateApp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project
  attribute :name
  attribute :repo
  attribute :branch
  attribute :webhook_deploy, :boolean, default: false
  attribute :builder, :string, default: "herokuish"

  attribute :app
  attr_reader :server_action_run

  validates :project, :repo, :branch, presence: true
  validates :webhook_deploy, inclusion: {in: [true, false]}

  validate :validate_prerequisites
  validate :validate_remote_repo_exists, if: -> { errors.empty? }
  validate :validate_remote_branch_exists, if: -> { errors.empty? }

  def prepare
    identity = source_identity
    return false unless valid?

    @prepared_source = identity
    true
  end

  def save(enqueue: true)
    return false unless @prepared_source || prepare

    App.transaction do
      project.lock!
      raise ServerAction::Conflict::Error unless source_identity == @prepared_source
      ServerAction::TargetValidation.app_context!(project)
      create_app!
      create_github_repo!
      @server_action_run = ServerAction::Enqueue.build(action: "apps.create", target: app)
      ServerAction::Enqueue.persist(server_action_run) if enqueue
    end

    true
  end

  private

  def source_identity
    return unless project

    {project_id: project.id, server_id: project.server_id, installation_id: project.account.github_installation&.id,
     name: name, repo: repo, branch: branch, builder: builder}
  end

  def validate_prerequisites
    return unless project

    ServerAction::TargetValidation.app_context!(project)
    errors.add(:base, "GitHub installation is required") unless account.github_installation
  end

  def create_app!
    self.app = project.apps.create!(
      server: project.server,
      builder: builder,
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
    account.github_installation.api_client
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
