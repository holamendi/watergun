class Account < ApplicationRecord
  has_many :api_tokens, dependent: :destroy
  has_many :apps, dependent: :destroy
  has_many :deployments, dependent: :destroy
  has_many :domains, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :servers, dependent: :destroy
  has_many :server_action_runs, dependent: :destroy
  has_many :server_action_logs, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :users, through: :memberships

  has_one :github_app, class_name: "Github::App", dependent: :destroy
  has_one :github_installation, class_name: "Github::Installation", dependent: :destroy
  has_many :github_repos, class_name: "Github::Repo", dependent: :destroy

  validates :name, presence: true

  def github_app_manifest
    @github_app_manifest ||= Github::AppManifest.new(account: self)
  end
end
