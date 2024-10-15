class Project < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  has_many :apps, dependent: :destroy
  has_many :deployments, through: :apps, source: :deployments
  has_many :services, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :account_id, conditions: -> { undiscarded }}

  broadcasts_to ->(project) { [project.account, :projects] }, inserts_by: :prepend

  def last_deployment
    deployments.success.last
  end
end
