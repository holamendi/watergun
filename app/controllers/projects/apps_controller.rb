class Projects::AppsController < Projects::BaseController
  before_action :set_app, except: [:index, :new, :create]

  def index
    @pagy, @apps = pagy(current_project.apps.kept.includes(:github_repo))
  end

  def new
    @app_creator = App::Creator.new(project: current_project)
  end

  def create
    @app_creator = App::Creator.new(app_creator_params)

    if @app_creator.create
      redirect_to project_app_path(current_project, @app_creator.app), notice: "App created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @deployments = @app.deployments.kept.recent.limit(5)
  end

  def edit
  end

  def update
    if @app.update(app_params)
      redirect_to edit_project_app_path(current_project, @app), notice: "App updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @app.discard!
    ServerAction::DestroyApp.run_later!(@app)

    redirect_to current_project, notice: "App deleted successfully."
  end

  private

  def app_creator_params
    params.require(:app_creator).permit(:name, :repo, :branch).merge(project: current_project)
  end

  def set_app
    @app = current_project.apps.kept.find(params[:id])
  end

  def render_form
    turbo_stream.replace(
      "app_form",
      partial: "projects/apps/form",
      locals: {project: current_project, app: @app}
    )
  end
end
