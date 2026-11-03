class Project < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { server.account }
  belongs_to :server

  has_many :apps, dependent: :destroy
  has_many :deployments, through: :apps, source: :deployments
  has_many :services, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :account_id, conditions: -> { undiscarded }}
  validate :validate_server_belongs_to_account

  def last_deployment
    deployments.success.last
  end

  def any_resources?
    apps.any? || services.any?
  end

  def status
    kept_apps = apps.select(&:kept?)
    return :pending if kept_apps.empty?
    return :deploying if kept_apps.any?(&:deploying?)
    return :error if kept_apps.any?(&:error?)
    return :active if kept_apps.any?(&:active?)
    :pending
  end

  private

  def validate_server_belongs_to_account
    errors.add(:server, "must belong to the project account") if server && server.account_id != account_id
  end
end
