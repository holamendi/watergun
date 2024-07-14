class ProjectsController < ApplicationController
  def index
    @projects = Project.kept
  end

  def show
    @project = current_account.projects.kept.find(params[:id])
    @app = App.new
    @app.build_github_repo
    @apps = @project.apps.kept
    @services = @project.services.kept
    @service = Service.new
  end

  def new
    @project = current_account.projects.new
  end

  def create
    @project = current_account.projects.new(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project was successfully created."
    else
      render turbo_stream: turbo_stream.replace(
        "project_form",
        partial: "projects/form",
        locals: {
          project: @project
        }
      )
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @project.discard

    redirect_to projects_path, notice: "Project was successfully destroyed."
  end

  private

  def set_project
    @project = current_account.projects.kept.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end
end
