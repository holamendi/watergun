class Project::DestroyProject
  def initialize(project)
    @project = project
  end

  def destroy
    ServerAction::Enqueue.build(action: ServerActions::DestroyProject, target: @project)
    @project.discard
    ServerAction::Enqueue.call(action: ServerActions::DestroyProject, target: @project)
  end
end
