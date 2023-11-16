class Current < ActiveSupport::CurrentAttributes
  attribute :membership, :org, :server, :session, :user

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
  end
end
