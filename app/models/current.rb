class Current < ActiveSupport::CurrentAttributes
  attribute :account,
    :accepting_server_action,
    :executing_server_action,
    :api_token,
    :membership,
    :project,
    :server,
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
    self.server ||= account.servers.first
  end

  def api_token=(api_token)
    super
    return unless api_token

    self.account = api_token.account
    self.server ||= account.servers.first
  end
end
