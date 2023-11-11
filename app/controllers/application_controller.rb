class ApplicationController < ActionController::Base
  before_action :authenticate_session!

  helper_method :current_user, :current_org, :current_membership, :current_session

  def current_membership
    Current.membership
  end

  def current_org
    Current.org
  end

  def current_user
    Current.user
  end

  def current_session
    Current.session
  end

  private

  def authenticate_session!
    return if (Current.session = Session.find_by_active_token(cookies.encrypted[:session_token]))

    redirect_to new_session_path, notice: "Please sign in"
  end
end
