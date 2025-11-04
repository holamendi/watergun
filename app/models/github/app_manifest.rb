# frozen_string_literal: true

class Github::AppManifest
  include Rails.application.routes.url_helpers

  DEFAULT_NAME = "Watergun"
  DEFAULT_DESCRIPTION = "A private GitHub App for managing your Watergun projects"
  DEFAULT_EVENTS = %w[check_suite push]
  DEFAULT_PERMISSIONS = {
    checks: "read",
    contents: "read"
  }

  def initialize(account:, name: DEFAULT_NAME, description: DEFAULT_DESCRIPTION)
    @account = account
    @name = name
    @description = description
  end

  def registration_url
    "https://github.com/settings/apps/new?state=#{registration_state}"
  end

  def to_param
    {
      name: @name,
      description: @description,
      public: false,
      url: root_url,
      redirect_url: github_app_registrations_callback_url,
      setup_url: callback_github_installations_url,
      default_permissions: DEFAULT_PERMISSIONS,
      default_events: DEFAULT_EVENTS,
      hook_attributes: {url: github_events_url}
    }.to_json
  end

  private

  def registration_state
    @account.signed_id(purpose: :github_app_registration)
  end
end
