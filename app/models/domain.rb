class Domain < ApplicationRecord
  include Discard::Model

  has_paper_trail

  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  str_enum :status, [:pending, :active, :deleting, :deleted, :error], default: :pending

  scope :ssl_enabled, -> { where(ssl_enabled: true) }
  scope :ssl_disabled, -> { where(ssl_enabled: false) }

  validates :hostname, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :ssl_enabled, inclusion: {in: [true, false]}

  after_create_commit -> { ServerActions::CreateDomain.perform_later!(self) }
  after_update_commit -> { broadcast_refresh_to(app) }
  after_discard -> { ServerActions::DestroyDomain.perform_later!(self) }

  def resolves_to_server?
    Resolv.getaddress(hostname) == app.server.public_ip
  rescue Resolv::ResolvError
    false
  end

  def url
    "#{scheme}://#{hostname}"
  end

  def scheme
    ssl_enabled ? "https" : "http"
  end
end
