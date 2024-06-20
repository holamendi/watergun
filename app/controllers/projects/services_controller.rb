module Projects
  class ServicesController < BaseController
    def create
      @service = current_project.services.new(service_params)

      if @service.save
        ServerActions::CreateService.perform_later!(@service)
        if params[:link_to_apps].present?
          current_project.apps.each do |app|
            service_link = app.service_links.create!(service: @service)
            ServerActions::LinkService.perform_later!(service_link)
          end
        end
        redirect_to current_project, notice: "Service created successfully."
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
