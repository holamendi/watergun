class GithubRepo < ApplicationRecord
  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  validates :repo, :branch, presence: true
  # validates :repo, format: {with: %r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9-]+\z}}, allow_blank: true
  validate :validate_remote_repo_exists
  validate :validate_remote_branch_exists

  before_save { self.private = remote_repo.private? }

  memoize def remote_repo
    octokit_client.repo(repo)
  rescue Octokit::NotFound, Octokit::InvalidRepository
    nil
  end

  memoize def remote_branch
    octokit_client.branch(repo, branch)
  rescue Octokit::NotFound
    nil
  end

  def remote_commit(sha)
    octokit_client.commit(repo, sha)
  rescue Octokit::UnprocessableEntity
    nil
  end

  memoize def octokit_client
    if org.github_access_token
      Octokit::Client.new(access_token: org.github_access_token.token)
    else
      Octokit::Client.new
    end
  end

  private

  def validate_remote_repo_exists
    return if errors.where(:repo).any?
    return if remote_repo

    errors.add(:repo, "does not exist")
  end

  def validate_remote_branch_exists
    return if errors.where(:repo).any? || errors.where(:branch).any?
    return if remote_branch

    errors.add(:branch, "does not exist")
  end
end
