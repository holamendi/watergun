class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :set_source
  before_action :authenticate!

  helper_method :current_user, :current_account, :current_membership, :current_session, :current_server

  def current_account
    Current.account
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

  def notify(message, type: :notice)
    turbo_stream.prepend("toasts", partial: "shared/toast", locals: {message:, type:})
  end

  def notify_error(message)
    notify(message, type: :error)
  end

  def set_source
    Current.source = :web
  end

  def sign_in(user)
    session = user.sessions.create!
    cookies.signed.permanent[:session_token] = {value: session.token, http_only: true, same_site: :lax}
    Current.session = session
  end

  def authenticate!
    return if (Current.session = Session.find_by_active_token(cookies.signed[:session_token]))

    redirect_to "/login", notice: "Please sign in"
  end

  def not_found!
    raise ActiveRecord::RecordNotFound
  end
end
