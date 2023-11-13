module Dokku
  class Log < ApplicationRecord
    belongs_to :dokku_event
    belongs_to :org
  end
end
