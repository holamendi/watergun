class ApplicationRecord < ActiveRecord::Base
  include ActionView::RecordIdentifier

  primary_abstract_class

  scope :recent, ->(column_name = :created_at) { order(column_name => :desc) }
end
