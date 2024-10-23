module Projects
  class ServicesController < BaseController
    before_action :set_service, only: [:show, :edit, :update, :destroy]

    def new
      @service = @project.services.new
    end

    def create
      @service = @project.services.new(service_params)

      if @service.save
        ServerActions::CreateService.run_later!(@service)

        @project.apps.kept.each do |app|
          ServiceLink::Creator.new(
            service: @service,
            app: app,
            env_name: "INTERNAL_#{SecureRandom.alphanumeric(4).upcase}_URL"
          ).create
        end

        redirect_to project_path(@project), notice: "Service created"
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
        redirect_to edit_project_service_path(@project, @service), notice: "Service updated successfully."
      else
        render :edit, status: :unprocessable_entity
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

    def service_params
      params.require(:service).permit(:name, :service_type)
    end

    def update_service_params
      params.require(:service).permit(:name)
    end
  end
end
