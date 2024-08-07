module GithubRepo::Remote
  extend ActiveSupport::Concern

  included do
    attr_accessor :skip_remote_validations

    with_options unless: :skip_remote_validations do
      validate :validate_remote_repo_exists, :validate_remote_branch_exists

      before_save { self.private = remote_repo.private? }
    end
  end

  def remote_repo
    octokit_client.repo(repo)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  def remote_branch
    octokit_client.branch(repo, branch)
  rescue Octokit::NotFound
    nil
  end

  def remote_commit(sha)
    octokit_client.commit(repo, sha)
  rescue Octokit::UnprocessableEntity
    nil
  end

  def octokit_client
    if account.github_access_token
      Octokit::Client.new(access_token: account.github_access_token.token)
    else
      Octokit::Client.new
    end
  end

  private

  def validate_remote_repo_exists
    return if errors.where(:repo).present?

    errors.add(:repo, "does not exist") unless remote_repo
  end

  def validate_remote_branch_exists
    return if errors.where(:repo).present? || errors.where(:branch).present?

    errors.add(:branch, "does not exist") unless remote_branch
  end
end
