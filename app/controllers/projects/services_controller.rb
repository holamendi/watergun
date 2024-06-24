module Projects
  class ServicesController < BaseController
    def create
      @service = current_project.services.new(service_params.merge(name: SecureRandom.hex(4)))

      if @service.save
        if true # params[:link_to_apps].present?
          current_project.apps.each do |app|
            app.service_links.create!(service: @service)
          end
        end
        redirect_to current_project, notice: "Service created successfully.", status: :see_other
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
      @service = @app.services.kept.find(params[:id])
      service_link = @service.service_links.kept.find_by(app: @app)

      service_link.discard!
      unlink_action = ServerActions::UnlinkService.perform_later!(service_link)
      @service.discard!
      ServerActions::DestroyService.perform_later!(@service, depends_on: unlink_action)

      redirect_to app_services_path(@app), notice: "Service scheduled for deletion"
    end

    private

    def service_params
      params.require(:service).permit(:name, :service_type)
    end
  end
end
