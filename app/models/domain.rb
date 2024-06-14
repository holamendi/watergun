class Domain < ApplicationRecord
  include Discard::Model

  has_paper_trail

  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  enum status: {
    pending: 0,
    created: 1,
    destroyed: 2
  }, _default: :pending, _prefix: true

  validates :hostname, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :ssl_enabled, inclusion: {in: [true, false]}

  def resolves_to_server?
    Resolv.getaddress(hostname) == app.server.public_ip
  rescue Resolv::ResolvError
    false
  end
end
