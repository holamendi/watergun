class Projects::ServicesController < Projects::BaseController
  before_action :set_service, only: [:show, :edit, :update, :destroy]

  def new
    @service_creator = Service::Creator.new(project: @project)
  end

  def create
    @service_creator = Service::Creator.new(create_service_params)

    if @service_creator.create
      redirect_to project_service_path(@project, @service_creator.service), notice: "Service created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @service.update(service_params)
      render turbo_stream: [stream_toast("Service updated"), render_form]
    else
      render turbo_stream: render_form, status: :unprocessable_entity
    end
  end

  def destroy
    Service::Destroyer.new(@service).destroy
    redirect_to @project, notice: "Service destroyed"
  end

  private

  def set_service
    @service = @project.services.kept.find(params[:id])
  end

  def create_service_params
    params.require(:service_creator).permit(:name, :service_type).merge(project: @project)
  end

  def service_params
    params.require(:service).permit(:name, :service_type)
  end

  def update_service_params
    params.require(:service).permit(:name)
  end

  def render_form
    turbo_stream.replace("service_form", partial: "projects/services/form", locals: {project: @project, service: @service})
  end
end
