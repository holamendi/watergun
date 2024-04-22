module DeploySources
  class GithubRepo < DeploySource
    belongs_to :app, inverse_of: :github_repo

    store_attribute :data, :repo, :string
    store_attribute :data, :branch, :string, default: "main"
    store_attribute :data, :private, :boolean, default: false

    validates :repo, :branch, :private, presence: true
    validates :repo, format: {with: %r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9-]+\z}}
  end
end
