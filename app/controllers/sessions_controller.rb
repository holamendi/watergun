class SessionsController < ApplicationController
  skip_before_action :authenticate

  layout "sessions"

  def new
    redirect_to root_path if Current.session

    @session = Session.new
  end

  def create
    @user = User.authenticate_by(session_params)

    if @user
      sign_in(@user)
      redirect_to root_path
    else
      flash.now[:error] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    Session.find_by_active_token(cookies.signed[:session_token])&.destroy
    cookies.delete(:session_token)
    redirect_to login_path, notice: "Logged out", status: :see_other
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
