class Current < ActiveSupport::CurrentAttributes
  attribute :membership,
    :org,
    :server,
    :server_event_source,
    :session,
    :user

  def session=(session)
    super
    return unless session

    self.server_event_source = "web"
    self.user = session.user
  end

  def user=(user)
    super
    return unless user

    self.membership = user.memberships.first
    self.org = membership.org
    self.server = org.servers.first
  end
end
