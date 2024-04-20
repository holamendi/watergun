module DeploySources
  class Github < DeploySource
    store_attribute :data, :repository, :string
    store_attribute :data, :branch, :string, default: "main"

    validates :repository, :branch, presence: true
  end
end
