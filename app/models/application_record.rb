class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.enum_keys(*keys)
    keys.each_with_object({}) { |key, hash| hash[key] = key.to_s }
  end
end
