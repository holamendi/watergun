class Current < ActiveSupport::CurrentAttributes
  attribute :api_token,
    :app,
    :membership,
    :account,
    :github_integration,
    :project,
    :server,
    :service,
    :session,
    :source,
    :user

  def session=(session)
    super
    return unless session

    self.user = session.user
  end

  def user=(user)
    super
    return unless user

    self.membership = user.memberships.first
    self.account = membership.account
    self.server = account.servers.first
    self.github_integration = account.github_integration
  end

  def api_token=(api_token)
    super
    return unless api_token

    self.account = api_token.account
    self.server = account.servers.first
  end
end
