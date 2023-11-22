class ApplicationController < ActionController::Base
  before_action :authenticate_session!

  helper_method :current_user, :current_org, :current_membership, :current_session

  private

  def authenticate_session!
    return if (Current.session = Session.find_by_active_token(cookies.encrypted[:session_token]))

    redirect_to login_path, notice: "Please sign in"
  end
end
