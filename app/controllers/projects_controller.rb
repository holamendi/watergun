class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  def index
    @projects = Current.account.projects.kept.includes(:apps, :services)
  end

  def show
    @apps = @project.apps.kept.includes(:github_repo, :containers)
    @services = @project.services.kept.includes(:linked_apps)
  end

  def new
    @project = Current.account.projects.new(server: Current.server)
  end

  def create
    @project = Current.account.projects.new(server: Current.server, **project_params)

    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project updated"
    else
      render :edit
    end
  end

  def destroy
    Project::DestroyProject.new(@project).destroy
    redirect_to projects_path, notice: "Project destroyed"
  end

  private

  def set_project
    @project = Current.account.projects.kept.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :server_id)
  end
end
