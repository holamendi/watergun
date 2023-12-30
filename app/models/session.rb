# == Schema Information
#
# Table name: sessions
#
#  id         :integer          not null, primary key
#  expires_at :datetime         not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_sessions_on_expires_at  (expires_at)
#  index_sessions_on_token       (token) UNIQUE
#  index_sessions_on_user_id     (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Session < ApplicationRecord
  has_secure_token length: 32

  belongs_to :user

  attribute :expires_at, :datetime, default: -> { 1.month.from_now }

  scope :active, -> { where(expires_at: Time.current..) }

  validates :expires_at, presence: true
  validates :token, presence: true, uniqueness: true

  def active?
    expires_at > Time.current
  end

  def expired?
    !active?
  end

  def self.find_by_active_token(token)
    active.find_by(token: token)
  end
end
