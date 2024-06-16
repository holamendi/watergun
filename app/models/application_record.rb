class ApplicationRecord < ActiveRecord::Base
  include Memery

  primary_abstract_class

  scope recent: -> { order(created_at: :desc) }
end
