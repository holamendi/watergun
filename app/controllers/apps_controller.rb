class AppsController < ApplicationController
  before_action :set_app, only: [:show, :edit, :update, :destroy, :activity]

  def index
    @apps = current_server.apps
  end

  def new
    @app = current_server.apps.new
  end

  def create
    @app = current_server.apps.new(app_params)

    if @app.save
      @app.server_events.create!(
        event_type: "apps.create",
        source: "web"
      )
      redirect_to app_path(@app), notice: "App created successfully."
    else
      render :new
    end
  end

  def show
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
    @app.destroy
    current_server.server_events.create!(
      event_type: "apps.destroy",
      source: "web",
      args: {
        dokku_app: @app.dokku_name
      }
    )

    redirect_to apps_path, notice: "App deleted successfully."
  end

  def activity
    @server_events = @app.server_events.order(created_at: :desc).limit(50)
  end

  private

  def app_params
    params.require(:app).permit(:name, :git_repo)
  end

  def set_app
    @app = current_server.apps.find(params[:id])
  end
end
