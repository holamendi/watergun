class Github::CreateHookJob < ApplicationJob
  queue_as :default

  def perform(github_repo)
    hook = Github::Hook.create!(
      account: github_repo.account,
      github_repo:,
      events: %w[push check_suite]
    )

    github_repo.github_integration.api_client.create_hook(
      github_repo.repo,
      "web",
      {
        url: Rails.application.routes.url_helpers.github_events,
        content_type: "json",
        secret: hook.secret
      },
      events: %w[push check_suite]
    )
  end
end
