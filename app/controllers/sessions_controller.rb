class SessionsController < ApplicationController
  skip_before_action :authenticate_session!

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
    @session.destroy!
    redirect_to sessions_url, notice: "Session was successfully destroyed.", status: :see_other
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
