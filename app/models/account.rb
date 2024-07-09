class Account < ApplicationRecord
  has_secure_token :first_signup_token

  has_many :api_tokens, dependent: :destroy
  has_many :apps, dependent: :destroy
  has_many :deployments, dependent: :destroy
  has_many :domains, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :server_actions, dependent: :destroy
  has_many :server_action_logs, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :users, through: :memberships

  has_one :github_access_token, dependent: :destroy

  validates :name, presence: true
end
