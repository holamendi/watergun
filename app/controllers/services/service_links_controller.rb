module Services
  class ServiceLinksController < BaseController
    def index
      @service_links = @service.service_links.kept.joins(:app).order("apps.name")
    end

    def new
      @service_link = @service.service_links.new
    end

    def create
      @service_link = @service.service_links.new(service_link_params)

      if @service_link.save
        redirect_to service_service_links_path(@service), notice: "Service link created successfully."
      else
        render :new
      end
    end

    def destroy
      @service_link = @service.service_links.find(params[:id])
      @service_link.discard!
      redirect_to service_service_links_path(@service), notice: "Service link deleted successfully."
    end

    private

    def service_link_params
      params.require(:service_link).permit(:app_id)
    end
  end
end
