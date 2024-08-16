class RootController < ApplicationController
  def index
    if last_visited_project
      redirect_to project_path(last_visited_project)
    else
      redirect_to projects_path
    end
  end

  private

  def last_visited_project
    Current.user.projects.kept.find_by(id: Current.user.last_visited_project_id)
  end
end
