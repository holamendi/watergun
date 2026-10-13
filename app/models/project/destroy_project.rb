class Project::DestroyProject
  def initialize(project)
    @project = project
  end

  def destroy
    ServerAction::Enqueue.build(action: "projects.destroy", target: @project)
    @project.discard
    ServerAction::Enqueue.call(action: "projects.destroy", target: @project)
  end
end
