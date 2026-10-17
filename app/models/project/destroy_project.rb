class Project::DestroyProject
  def initialize(project)
    @project = project
  end

  def destroy
    Project.transaction do
      @project.lock!
      run = ServerAction::Enqueue.call(action: "projects.destroy", target: @project)
      @project.discard!
      run
    end
  end
end
