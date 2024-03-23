class Org < ApplicationRecord
  has_many :apps, dependent: :destroy
  has_many :actions, dependent: :destroy
  has_many :action_logs, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :server_identities, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :users, through: :memberships

  has_one :github_access_token, dependent: :destroy

  validates :name, presence: true
end
