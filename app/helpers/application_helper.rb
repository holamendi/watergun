module ApplicationHelper
  def status_badge_class(status)
    {
      queued: "badge-warning",
      running: "badge-primary",
      success: "badge-success",
      failure: "badge-error"
    }[status&.to_sym] || "badge-default"
  end
end
