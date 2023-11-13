class App < ApplicationRecord
  belongs_to :org
  belongs_to :server

  has_many :dokku_events, as: :eventable, class_name: "Dokku::Event", dependent: :destroy
end
