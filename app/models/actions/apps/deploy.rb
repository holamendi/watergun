module Actions
  module Apps
    class Deploy < Action
      store_attribute :payload, :dokku_id, :string
      store_attribute :payload, :source, :string
      store_attribute :payload, :github_repository, :string
      store_attribute :payload, :github_branch, :string
      store_attribute :payload, :github_commit_sha, :string

      validates :dokku_id, presence: true
      validates :source, inclusion: {in: %w[github]}
      validates :github_repository, :github_branch, :github_commit_sha, presence: true, if: -> { source == "github" }
    end
  end
end
