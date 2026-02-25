module TurboStreamActionsHelper
  def redirect(url)
    turbo_stream_action_tag(:redirect, url: url)
  end

  def close_dialog(target_id)
    turbo_stream_action_tag(:close_dialog, target: target_id)
  end
end

Turbo::Streams::TagBuilder.prepend(TurboStreamActionsHelper)
