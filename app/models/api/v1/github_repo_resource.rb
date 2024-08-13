class Api::V1::GithubRepoResource < Api::ApplicationResource
  attributes :repo,
    :branch,
    :private
end
