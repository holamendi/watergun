class ApplicationRecord < ActiveRecord::Base
  include Memery

  primary_abstract_class
end
