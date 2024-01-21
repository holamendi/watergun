class ServicesController < ApplicationController
  before_action :set_service, except: [:index, :new, :create, :select_git_repo]

  def index
    @services = current_server.services.kept
  end

  def new
    @service = current_server.services.new
  end

  def create
    @service = current_server.services.new(service_params.merge(status: "creating"))

    if @service.save
      redirect_to service_path(@service), notice: "Service created successfully."
    else
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to edit_service_path(@service), notice: "Service updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @service.discard!
    redirect_to services_path, notice: "Service deleted successfully."
  end

  def deploy
    @service.deploy!
    redirect_to service_path(@service), notice: "Service deploy started."
  end

  def restart
    @service.restart!
    redirect_to service_path(@service), notice: "Service restart started."
  end

  def activity
    @server_events = @service.server_events.order(created_at: :desc).limit(50)
  end

  def select_git_repo
  end

  private

  def service_params
    params.require(:service).permit(:name, :service_type)
  end

  def set_service
    @service = current_server.services.kept.find(params[:id])
  end
end
