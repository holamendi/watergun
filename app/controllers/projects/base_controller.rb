module Projects
  class BaseController < ApplicationController
    before_action :set_project

    private

    def set_project
      @project = Current.account.projects.kept.find(params[:project_id])
    end
  end
end
