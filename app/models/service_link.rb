class ServiceLink < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true
  belongs_to :service, touch: true
  belongs_to :env_variable

  enum :status, %w[pending active deleting error].index_by(&:itself), default: :pending

  validates :app, uniqueness: {scope: :service, conditions: -> { undiscarded }}
end
