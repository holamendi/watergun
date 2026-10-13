class Project < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { server.account }
  belongs_to :server

  has_many :apps, dependent: :destroy
  has_many :deployments, through: :apps, source: :deployments
  has_many :services, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :account_id, conditions: -> { undiscarded }}
  validate :server_belongs_to_account
  validate :server_unchanged_with_resources, on: :update

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

  def server_unchanged_with_resources
    if will_save_change_to_server_id? && any_resources?
      errors.add(:server, "cannot change while the project has resources")
    end
  end

  def server_belongs_to_account
    if server && server.account_id != account_id
      errors.add(:server, "must belong to the project account")
    end
  end
end
