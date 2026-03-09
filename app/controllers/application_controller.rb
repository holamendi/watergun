class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  before_action :authenticate
  before_action :set_source

  private

  def stream_toast(message, title: nil, type: :notice, link_text: nil, link_url: nil)
    turbo_stream.append("toasts", partial: "shared/toast", locals: {message:, title:, type:, link_text:, link_url:})
  end

  def set_source
    Current.source = :web
  end

  def not_found!
    raise ActiveRecord::RecordNotFound
  end
end
