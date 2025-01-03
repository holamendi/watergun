module TurboStreamResponder
  extend ActiveSupport::Concern

  private

  def stream_toast(message)
    turbo_stream.append("toasts", partial: "shared/toast", locals: {message: message})
  end

  def render_form_response(form_id, resource, partial_path, locals = {})
    turbo_stream.replace(form_id, partial: partial_path, locals: locals.merge(resource: resource))
  end
end
