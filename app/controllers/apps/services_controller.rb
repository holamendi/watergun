module Apps
  class ServicesController < BaseController
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

        ServerActions::CreateService.perform_later!(@service)
        ServerActions::LinkService.perform_later!(service_link)

        redirect_to app_services_path(@app), notice: "Service created successfully."
      else
        render :new
      end
    end

    def destroy
      @service = @app.services.kept.find(params[:id])
      service_link = @service.service_links.kept.find_by(app: @app)

      service_link.discard!
      ServerActions::UnlinkService.perform_later!(service_link)
      @service.discard!
      ServerActions::DestroyService.perform_later!(@service)

      redirect_to app_services_path(@app), notice: "Service scheduled for deletion"
    end

    private

    def service_params
      params.require(:service).permit(:name, :service_type)
    end
  end
end
