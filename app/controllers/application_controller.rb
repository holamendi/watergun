class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :set_source
  before_action :authenticate

  private

  def append_toast(message, title: nil, type: :notice)
    turbo_stream.append("toasts", ToastComponent.new(message:, title:, type:))
  end

  def set_source
    Current.source = :web
  end

  def sign_in(user)
    session = user.sessions.create!
    cookies.signed.permanent[:session_token] = {value: session.token, http_only: true, same_site: :lax}
    Current.session = session
  end

  def authenticate
    session = Session.find_by_active_token(cookies.signed[:session_token])
    if session
      Current.session = session
    else
      redirect_to "/login", notice: "Please sign in"
    end
  end

  def not_found!
    raise ActiveRecord::RecordNotFound
  end
end
