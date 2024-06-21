class Project < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }
  has_many :apps, dependent: :destroy
  has_many :services, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :org_id, conditions: -> { undiscarded }}
end
