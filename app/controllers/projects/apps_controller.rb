class Projects::AppsController < Projects::BaseController
  before_action :set_app, except: [:index, :new, :create]

  def index
    @pagy, @apps = pagy(@project.apps.kept.includes(:github_repo))
  end

  def new
    @create_app = App::CreateApp.new(project: @project)
  end

  def create
    @create_app = App::CreateApp.new(create_app_params.merge(project: @project))

    if @create_app.save
      redirect_to project_app_deployments_path(@project, @create_app.app), notice: "App created"
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    redirect_to project_app_deployments_path(@project, @app)
  end

  def edit
    redirect_to project_app_settings_path(@project, @app)
  end

  def update
    if @app.update(app_params)
      render turbo_stream: [
        stream_toast("App updated"),
        render_form
      ]
    else
      render turbo_stream: render_form, status: :unprocessable_content
    end
  end

  def destroy
    App::DestroyApp.new(@app).destroy
    redirect_to @project, notice: "App destroyed"
  end

  private

  def app_params
    params.require(:app).permit(:name)
  end

  def create_app_params
    params.require(:create_app).permit(:name, :repo, :branch, :webhook_deploy)
  end

  def set_app
    @app = @project.apps.kept.includes(:services, :server, :github_repo, :default_domain, :containers).find(params[:id])
  end

  def render_form
    turbo_stream.replace("app_form", partial: "projects/apps/form", locals: {project: @project, app: @app})
  end
end
