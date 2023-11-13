module Dokku
  class Event < ApplicationRecord
    belongs_to :eventable, polymorphic: true
    belongs_to :membership, optional: true
    belongs_to :org
    belongs_to :server

    has_one :log, dependent: :destroy
  end
end
