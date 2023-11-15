class App < ApplicationRecord
  belongs_to :org
  belongs_to :server

  has_many :dokku_events, as: :eventable, class_name: "Dokku::Event", dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :server_id}

  before_validation -> { self.dokku_name = name&.parameterize }, on: :create
  after_create_commit :create_dokku_app!
  after_destroy_commit :destroy_dokku_app!

  def create_dokku_app!
    Dokku::CommandJob.perform_later(server:, eventable: self, command: "apps:create #{dokku_name}")
  end

  def destroy_dokku_app!
    Dokku::CommandJob.perform_later(server:, eventable: server, command: "apps:destroy --force #{dokku_name}")
  end
end
