class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :sessions, dependent: :destroy
end
