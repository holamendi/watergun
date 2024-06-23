module Projects
  module Apps
    class DomainsController < BaseController
      def index
        @domains = current_app.domains.kept
      end

      def new
        @domain = current_app.domains.new
      end

      def create
        @domain = current_app.domains.new(domain_params)

        if @domain.save
          redirect_to edit_app_path(current_app), notice: "Domain added successfully."
        else
          render :new
        end
      end

      def destroy
        @domain = current_app.domains.kept.find(params[:id])
        @domain.discard!
        redirect_to project_app_domains_path(current_project, current_app), notice: "Domain removed successfully."
      end

      private

      def domain_params
        params.require(:domain).permit(:hostname)
      end
    end
  end
end
