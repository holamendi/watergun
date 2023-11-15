module Dokku
  class Event < ApplicationRecord
    belongs_to :eventable, polymorphic: true
    belongs_to :membership, optional: true
    belongs_to :org
    belongs_to :server

    has_one :dokku_log, class_name: "Dokku::Log", dependent: :destroy

    enum status: {
      running: "running",
      success: "success",
      failure: "failure"
    }, _prefix: true

    validates :command, presence: true
  end
end
