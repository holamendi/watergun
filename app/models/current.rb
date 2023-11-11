class Current < ActiveSupport::CurrentAttributes
  attribute :membership, :org, :session, :user

  def session=(session)
    super
    return unless session

    self.user = session.user
    self.membership = user.memberships.first
    self.org = membership.org
  end
end
