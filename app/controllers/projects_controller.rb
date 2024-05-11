class ProjectsController < ApplicationController
  before_action :set_project, except: [:index, :new, :create]

  def index
    @pagy, @projects = pagy(current_server.projects.kept)
  end

  def new
    @project = current_server.projects.new
  end

  def create
    @project = current_server.projects.new(project_params)

    if @project.save
      ServerActions::CreateProject.perform_later!(@project)
      redirect_to project_path(@project), notice: "Project created successfully."
    else
      render :new
    end
  end

  def show
    @deployments = @project.deployments.kept.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to edit_project_path(@project), notice: "Project updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.discard!
    ServerActions::DestroyProject.perform_later!(@project)
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end

  def set_project
    @project = current_server.projects.kept.find(params[:id])
  end
end
