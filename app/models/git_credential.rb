class GitCredential < ApplicationRecord
  include BelongsToOrg

  enum provider: {
    github: 0
  }, _prefix: true, _default: "github"

  def repos
    client.repo
  end

  private

  def client
    Octokit::Client.new(access_token: personal_access_token, per_page: 100)
  end
end
