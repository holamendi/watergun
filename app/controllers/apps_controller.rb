class AppsController < ApplicationController
  before_action :set_app, except: [:index, :new, :create]

  def index
    @pagy, @apps = pagy(current_server.apps.kept)
  end

  def new
    @app = current_server.apps.new
  end

  def create
    @app = current_server.apps.new(app_params)

    if @app.save
      ServerActions::CreateApp.perform_later!(@app)
      redirect_to app_path(@app), notice: "App created successfully."
    else
      render :new
    end
  end

  def show
    @deployments = @app.deployments.kept.order(created_at: :desc)
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

  def destroy
    @app.discard!

    @app.service_links.kept.each do |service_link|
      service_link.discard!
      ServerActions::UnlinkService.perform_later!(service_link)
      service_link.service.discard!
      ServerActions::DestroyService.perform_later!(service_link.service)
    end

    ServerActions::DestroyApp.perform_later!(@app)
    redirect_to apps_path, notice: "App deleted successfully."
  end

  private

  def app_params
    params.require(:app).permit(:name)
  end

  def set_app
    @app = current_server.apps.kept.find(params[:id])
  end
end
