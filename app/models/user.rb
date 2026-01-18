class User < ApplicationRecord
  # Single theme supported - custom dark design system
  THEMES = %w[watergun].freeze

  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :projects, through: :accounts
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :theme, inclusion: {in: THEMES}, allow_nil: true
end
