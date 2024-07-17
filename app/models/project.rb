class Project < ApplicationRecord
  include Discard::Model

  broadcasts_refreshes

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  has_many :apps, dependent: :destroy
  has_many :services, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :account_id, conditions: -> { undiscarded }}
end
