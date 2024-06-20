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
      @app = @project.apps.new(app_params.merge(name: app_params.dig(:github_repo_attributes, :repo)&.split("/")&.last))

      if @app.save
        ServerActions::CreateApp.perform_later!(@app)
        render turbo_stream:
      else
        render turbo_stream: turbo_stream.replace(
          @app,
          partial: "projects/apps/form",
          locals: {
            project: current_project,
            app: @app
          }
        )
      end
    end

    def show
      @deployments = @app.deployments.kept.recent.limit(5)
    end

    def edit
    end

    def update
      if @app.update(app_params)
        redirect_to edit_app_path(@app), notice: "App updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # TODO: move this logic to something more reusable
    def destroy
      @app.discard!
      ServerActions::DestroyApp.perform_later!(@app)

      @app.service_links.kept.includes(:service).each do |service_link|
        service_link.discard!
        unlink_action = ServerActions::UnlinkService.perform_later!(service_link)
        service_link.service.discard!
        ServerActions::DestroyService.perform_later!(service_link.service, depends_on: unlink_action)
      end

      redirect_to apps_path, notice: "App deleted successfully."
    end

    private

    def app_params
      params.require(:app).permit(:name, github_repo_attributes: %i[repo branch])
    end

    def set_app
      @app = current_project.apps.kept.find(params[:id])
    end
  end
end
