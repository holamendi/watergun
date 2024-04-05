class AppsController < ApplicationController
  before_action :set_app, except: [:index, :new, :create]

  def index
    @apps = current_server.apps.kept
  end

  def new
    @app = current_server.apps.new
  end

  def create
    @app = current_server.apps.new(app_params)

    if @app.save
      redirect_to app_path(@app), notice: "App created successfully."
    else
      render :new
    end
  end

  def show
    service_actions = Action.where(actionable_type: "Service", actionable_id: @app.services.ids)
    @recent_actions = @app.actions.or(service_actions).order(created_at: :desc).limit(10)
  end

  def edit
  end

  def update
    if @app.update(app_params)
      redirect_to edit_app_path(@app), notice: "App updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @app.service_links.discard_all
    @app.services.discard_all
    @app.discard!
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
