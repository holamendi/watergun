module Services
  class BaseController < ApplicationController
    before_action :set_service

    def set_service
      @service = current_server.services.kept.find(params[:service_id])
    end
  end
end
