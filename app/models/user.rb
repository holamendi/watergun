class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :orgs, through: :memberships
  has_many :sessions, dependent: :destroy
end
