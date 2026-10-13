class Project::DestroyProject
  def initialize(project)
    @project = project
  end

  def destroy
    ServerActions::DestroyProject.new(server: @project.server, actionable: @project).validate!
    @project.discard
    ServerActions::DestroyProject.run_later!(@project.server, @project)
  end
end
