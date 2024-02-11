class SessionsController < ApplicationController
  skip_before_action :authenticate!

  layout "sessions"

  def new
    redirect_to root_path if Session.find_by_active_token(cookies.encrypted[:session_token])

    @session = Session.new
  end

  def create
    @user = User.authenticate_by(session_params)

    if @user
      Current.session = @user.sessions.create!
      cookies.encrypted[:session_token] = {value: Current.session.token, expires: Current.session.expires_at}
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    Current.session&.destroy
    cookies.delete(:session_token)
    redirect_to login_path, notice: "Logged out", status: :see_other
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
