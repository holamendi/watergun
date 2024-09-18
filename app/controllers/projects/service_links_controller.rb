class Projects::ServiceLinksController < Projects::BaseController
  def create
    @service_link = @project.service_links.new(service_link_params)
    if @service_link.save
      redirect_to project_path(@project), notice: "Service link created successfully"
    else
      render :new, error: "Failed to create service link"
    end
  end

  def destroy
    @service_link = @project.service_links.find(params[:id])
    if @service_link.destroy
      redirect_to project_path(@project), notice: "Service link destroyed successfully"
    else
      redirect_to project_path(@project), error: "Failed to destroy service link"
    end
  end

  private

  def service_link_params
    params.require(:service_link).permit(:service_id)
  end
end
