module Projects
  class ServicesController < BaseController
    before_action :set_service, only: [:show, :edit, :update, :destroy]

    def create
      @service = current_project.services.new(service_params)

      if @service.save
        ServerAction::CreateService.run_later!(@service)

        if params[:link_to_apps].present?
          current_project.apps.kept.each do |app|
            link = @service.service_links.create!(app:)
            ServerAction::LinkService.run_later!(link)
          end
        end

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

    def show
    end

    def edit
    end

    def update
      if @service.update(service_params)
        redirect_to project_service_path(current_project, @service), notice: "Service updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @service.discard
        @service.service_links.kept.each do |service_link|
          ServerAction::UnlinkService.run_later!(service_link)
        end
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
