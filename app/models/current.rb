class Current < ActiveSupport::CurrentAttributes
  attribute :api_token,
    :membership,
    :org,
    :server,
    :server_event_source,
    :session,
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
    self.org = membership.org
    self.server = org.servers.first
  end

  def api_token=(api_token)
    super
    return unless api_token

    self.org = api_token.org
    self.server = org.servers.first
  end
end
