module ServerAction::ResourceKey
  def self.for(target)
    resource = case target
    when Deployment, Domain, StorageMount
      target.app
    when ServiceLink
      target.service
    else
      target
    end
    "#{resource.class.base_class.name.underscore}:#{resource.id}"
  end
end
