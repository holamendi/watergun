class MissionControl::BaseController < ActionController::Base
  include Authentication

  before_action :authenticate
  before_action :authorize_jobs_access

  private

  def authorize_jobs_access
    head :forbidden unless ENV.fetch("JOBS_ADMIN_USER_IDS", "").split(",").map(&:strip).include?(Current.user.id.to_s)
  end
end
