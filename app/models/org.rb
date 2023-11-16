class Org < ApplicationRecord
  has_many :apps, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :server_events, dependent: :destroy
  has_many :server_event_logs, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
end
