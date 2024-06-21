module ApplicationHelper
  def status_badge_class(status)
    {
      active: "badge-success",
      deleted: "badge-default",
      deleting: "badge-warning",
      deploying: "badge-warning",
      error: "badge-error",
      pending: "badge-warning",
      queued: "badge-warning",
      restarting: "badge-warning",
      running: "badge-primary",
      stopped: "badge-default",
      stopping: "badge-warning",
      success: "badge-success"
    }.fetch(status&.to_sym, "badge-default")
  end
end
