module Authentication
  extend ActiveSupport::Concern

  private

  def sign_in(user)
    session = user.sessions.create!
    cookies.signed.permanent[:session_token] = {value: session.token, http_only: true, same_site: :lax}
    Current.session = session
  end

  def authenticate
    if (session = Session.find_by_active_token(cookies.signed[:session_token]))
      restore_server_selection(session.user)
      Current.session = session
    else
      redirect_to login_path, notice: "Please sign in"
    end
  end

  def restore_server_selection(user)
    if (server_id = cookies.signed[:server_id])
      server = user.memberships.first&.account&.servers&.find_by(id: server_id)
      Current.server = server if server
    end
  end
end
