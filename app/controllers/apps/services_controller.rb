module Apps
  class ServicesController < ApplicationController
    before_action :set_app

    def index
      @service_links = @app.service_links.kept.joins(:service).order("services.name")
    end

    def new
      @service = current_server.services.new
    end

    def create
      @service = current_server.services.new(service_params)

      if @service.save
        service_link = @app.service_links.create!(service: @service)

        create_service_action = ServerActions::CreateService.perform_later!(@service)
        ServerActions::LinkService.perform_later!(service_link, depends_on: create_service_action)

        redirect_to app_services_path(@app), notice: "Service created successfully."
      else
        render :new
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

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def service_params
      params.require(:service).permit(:name, :service_type)
    end
  end
end
