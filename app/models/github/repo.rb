class Github::Repo < ApplicationRecord
  belongs_to :account
  belongs_to :app

  scope :kept, -> { joins(:app).merge(App.kept) }

  validates :repo, :branch, presence: true

  delegate :github_app, to: :account

  def web_url
    "https://github.com/#{repo}/tree/#{branch}"
  end
end
