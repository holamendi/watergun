module AppSources
  class Github < AppSource
    store_attribute :data, :repository, :string
    store_attribute :data, :branch, :string, default: "main"
  end
end
