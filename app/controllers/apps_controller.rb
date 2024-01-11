class AppsController < ApplicationController
  before_action :set_app, except: [:index, :new, :create, :select_git_repo]

  def index
    @apps = current_server.apps.kept
  end

  def new
    @app = current_server.apps.new
  end

  def create
    @app = current_server.apps.new(app_params.merge(status: "creating"))

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
    @app.discard!
    redirect_to apps_path, notice: "App deleted successfully."
  end

  def deploy
    @app.deploy!
    redirect_to app_path(@app), notice: "App deploy started."
  end

  def restart
    @app.restart!
    redirect_to app_path(@app), notice: "App restart started."
  end

  def activity
    @server_events = @app.server_events.order(created_at: :desc).limit(50)
  end

  def select_git_repo
  end

  private

  def app_params
    params.require(:app).permit(:name, :git_repo, :git_branch, :dokku_builder)
  end

  def set_app
    @app = current_server.apps.kept.find(params[:id])
  end
end
