class Server < ApplicationRecord
  has_secure_token :dokku_token, length: 32

  enum status: {
    active: "active",
    deprovisioning: "deprovisioning",
    error: "error",
    provisioning: "provisioning"
  }, prefix: true, default: "provisioning"

  belongs_to :org

  has_one :dokku_user, class_name: "Dokku::User", dependent: :destroy

  has_many :apps
  has_many :dokku_events, class_name: "Dokku::Event", dependent: :destroy
  has_many :dokku_logs, class_name: "Dokku::Log", dependent: :destroy

  store_attribute :data, :public_ip, :string

  after_create :create_dokku_user
end
z
