# == Schema Information
#
# Table name: orgs
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Org < ApplicationRecord
  has_many :apps, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :server_events, dependent: :destroy
  has_many :server_event_logs, dependent: :destroy
  has_many :users, through: :memberships

  has_one :git_credential, dependent: :destroy

  validates :name, presence: true
end
