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
      Current.session = session
    else
      redirect_to login_path, notice: "Please sign in"
    end
  end
end
