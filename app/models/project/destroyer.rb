class Project::Destroyer
  def initialize(project)
    @project = project
  end

  def destroy
    @project.discard
    ServerActions::DestroyProject.run_later!(@project)
  end
end
