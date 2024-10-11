class Projects::AppsController < Projects::BaseController
  before_action :set_app, except: [:index, :new, :create]

  def index
    @pagy, @apps = pagy(@project.apps.kept.includes(:github_repo))
  end

  def new
    @app_creator = App::Creator.new(project: @project)
  end

  def create
    @app_creator = App::Creator.new(create_app_params)

    if @app_creator.create
      redirect_to project_app_path(@project, @app_creator.app), notice: "App created"
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
      redirect_to edit_project_app_path(@project, @app), notice: "App updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    App::Destroyer.new(@app).destroy
    redirect_to @project, notice: "App destroyed"
  end

  private

  def app_params
    params.require(:app).permit(:name)
  end

  def create_app_params
    params.require(:app_creator).permit(:name, :repo, :branch).merge(project: @project)
  end

  def set_app
    @app = @project.apps.kept.find(params[:id])
  end

  def render_form
    turbo_stream.replace(
      "app_form",
      partial: "projects/apps/form",
      locals: {project: @project, app: @app}
    )
  end
end
