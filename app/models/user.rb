class User < ApplicationRecord
  has_secure_password

  generates_token_for :first_run, expires_in: 1.day do
    password_salt.last(10)
  end

  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :projects, through: :accounts
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :password, presence: true, on: :first_run
  validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
end
