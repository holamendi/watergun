class Project < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { server.account }
  belongs_to :server

  has_many :apps, dependent: :destroy
  has_many :deployments, through: :apps, source: :deployments
  has_many :services, dependent: :destroy
  has_many :service_links, through: :services

  store_attribute :data, :dokku_import, :boolean, default: false

  scope :dokku_imports, -> { where("data ->> 'dokku_import' = ?", "true") }

  validates :name, presence: true, uniqueness: {scope: :account_id, conditions: -> { undiscarded }}

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
end
