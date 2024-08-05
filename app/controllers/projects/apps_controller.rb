module Projects
  class AppsController < BaseController
    before_action :set_app, except: [:index, :new, :create]

    def index
      @pagy, @apps = pagy(current_project.apps.kept.includes(:github_repo))
    end

    def new
      @app = current_server.apps.new
    end

    def create
      @app = current_project.apps.new(app_params.merge(
        name: app_params.dig(:github_repo_attributes, :repo)&.split("/")&.last
      ))

      if @app.save
        ServerAction::CreateApp.run_later!(@app)
        redirect_to project_app_path(current_project, @app), notice: "App created"
      else
        render turbo_stream: render_form
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

    def app_params
      params.require(:app).permit(:name, github_repo_attributes: %i[repo branch])
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
end
