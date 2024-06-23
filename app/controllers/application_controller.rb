class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :authenticate!

  helper_method :current_user, :current_org, :current_membership, :current_session, :current_server

  def current_org
    Current.org
  end

  def current_membership
    Current.membership
  end

  def current_session
    Current.session
  end

  def current_user
    Current.user
  end

  def current_server
    Current.server
  end

  private

  def authenticate!
    return if (Current.session = Session.find_by_active_token(cookies.encrypted[:session_token]))

    redirect_to "/login", notice: "Please sign in"
  end
end
