module Projects
  class BaseController < ApplicationController
    before_action :set_project

    helper_method :current_project

    def current_project
      Current.project
    end

    private

    def set_project
      Current.project = Project.kept.find(params[:project_id])
    end
  end
end
