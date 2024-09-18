class Project::Destroyer
  def initialize(project)
    @project = project
  end

  def destroy!
    destroy_apps
    destroy_services
    @project.discard
  end

  private

  def destroy_apps
    @project.apps.kept.each { App::Destroyer.new(_1).destroy }
  end

  def destroy_services
    @project.services.kept.each { Service::Destroyer.new(_1).destroy }
  end
end
