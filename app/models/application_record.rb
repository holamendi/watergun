class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.enum_keys(*keys)
    keys.index_by(&:itself)
  end
end
