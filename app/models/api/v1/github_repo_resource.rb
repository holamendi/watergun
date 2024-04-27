module Api
  module V1
    class GithubRepoResource < ApplicationResource
      attributes :repo,
        :branch,
        :private
    end
  end
end
