class ServicesController < ApplicationController
  before_action :set_service, except: [:index, :new, :create]

  def index
    @services = current_server.services.kept
  end

  def new
    @service = current_server.services.new
  end

  def create
    @service = current_server.services.new(service_params.merge(status: "creating"))

    if @service.save
      ServerActions::CreateService.perform_later!(@service)
      redirect_to service_path(@service), notice: "Service creation scheduled"
    else
      render :new
    end
  end

  def show
    @latest_actions = @service.actions.order(created_at: :desc).limit(5)
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

  private

  def service_params
    params.require(:service).permit(:name, :service_type)
  end

  def set_service
    @service = current_server.services.kept.find(params[:id])
  end
end
