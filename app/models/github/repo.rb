class Github::Repo < ApplicationRecord
  belongs_to :account
  belongs_to :app, class_name: "::App"

  scope :kept, -> { joins(:app).merge(App.kept) }

  validates :repo, :branch, presence: true

  def web_url
    "https://github.com/#{repo}/tree/#{branch}"
  end
end
