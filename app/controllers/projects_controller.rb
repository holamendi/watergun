class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :destroy]
  def index
    @projects = Project.kept
  end

  def show
    @apps = @project.apps.kept
    @services = @project.services.kept
    @service = Service.new
    Current.user.visit_project!(@project)
  end

  def new
    @project = Current.account.projects.new
  end

  def create
    @project = Current.account.projects.new(project_params)

    if @project.save
      redirect_to @project, notice: "Project was successfully created."
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
    discard_apps
    discard_services

    redirect_to projects_path, notice: "Project destroyed"
  end

  private

  def set_project
    @project = Current.account.projects.kept.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end

  def discard_apps
    @project.apps.kept.each do |app|
      app.discard
      ServerAction::DestroyApp.run_later!(app)
    end
  end

  def discard_services
    @project.services.kept.each do |service|
      service.discard

      service.service_links.kept.each do |service_link|
        service_link.discard
        ServerAction::UnlinkService.run_later!(service_link)
      end

      ServerAction::DestroyService.run_later!(service)
    end
  end
end
