module Apps
  class DomainsController < ApplicationController
    before_action :set_app

    def index
      @domains = @app.domains.kept
    end

    def new
      @domain = @app.domains.new
    end

    def create
      @domain = @app.domains.new(domain_params)

      if @domain.save
        ServerActions::CreateDomain.perform_later!(@domain)
        redirect_to edit_app_path(@app), notice: "Domain added successfully."
      else
        render :new
      end
    end

    def destroy
      @domain = @app.domains.kept.find(params[:id])
      @domain.discard!
      ServerActions::DestroyDomain.perform_later!(@domain)
      redirect_to edit_app_path(@app), notice: "Domain removed successfully."
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def domain_params
      params.require(:domain).permit(:hostname)
    end
  end
end
