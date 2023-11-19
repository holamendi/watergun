class AppsController < ApplicationController
  before_action :set_app, only: [:show, :edit, :update, :destroy, :metrics, :logs]

  def index
    @apps = Current.server.apps
  end

  def new
    @app = Current.server.apps.new
  end

  def create
    @app = Current.server.apps.new(app_params)
    if @app.save
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
    redirect_to apps_path, notice: "App deleted successfully."
  end

  def metrics
  end

  def logs
  end

  private

  def app_params
    params.require(:app).permit(:name)
  end

  def set_app
    @app = Current.server.apps.find(params[:id])
  end
end
