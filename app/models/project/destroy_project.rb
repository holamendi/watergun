class Project::DestroyProject
  def initialize(project)
    @project = project
  end

  def destroy
    @project.discard
    ServerActions::DestroyProject.run_later!(@project.server, @project)
  end
end
