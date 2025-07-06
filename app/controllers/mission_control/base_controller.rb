class MissionControl::BaseController < ActionController::Base
  include Authentication

  before_action :authenticate
end
