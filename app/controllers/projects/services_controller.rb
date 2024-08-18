module Projects
  class ServicesController < BaseController
    before_action :set_service, only: [:show, :edit, :update, :destroy]

    def create
      @service = @project.services.new(service_params)

      if @service.save
        ServerAction::CreateService.run_later!(@service)

        redirect_to @project, notice: "Service created successfully."
      else
        render turbo_stream: turbo_stream.replace(
          "service_form",
          partial: "projects/services/form",
          locals: {
            project: @project,
            service: @service
          }
        )
      end
    end

    def show
    end

    def edit
    end

    def update
      if @service.update(service_params)
        redirect_to project_service_path(@project, @service), notice: "Service updated successfully."
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
  end
end
