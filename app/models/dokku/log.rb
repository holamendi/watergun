module Dokku
  class Log < ApplicationRecord
    belongs_to :dokku_event, class_name: "Dokku::Event", foreign_key: "dokku_event_id"
    belongs_to :org
  end
end
