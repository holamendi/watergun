module Projects
  class ServicesController < BaseController
    before_action :set_service, only: [:show, :destroy]

    def show
    end

    def create
      @service = current_project.services.new(service_params.merge(name: SecureRandom.hex(4)))

      if @service.save
        ServerAction::CreateService.run_later!(@service)
        redirect_to current_project, notice: "Service created successfully."
      else
        render turbo_stream: turbo_stream.replace(
          "service_form",
          partial: "projects/services/form",
          locals: {
            project: current_project,
            service: @service
          }
        )
      end
    end

    def destroy
      if @service.discard
        @service.service_links.discard_all
        ServerAction::DestroyService.run_later!(@service)
      end

      redirect_to current_project, notice: "Service scheduled for deletion"
    end

    private

    def set_service
      @service = current_project.services.kept.find(params[:id])
    end

    def service_params
      params.require(:service).permit(:name, :service_type)
    end
  end
end
