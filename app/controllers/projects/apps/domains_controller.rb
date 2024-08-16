class Projects::Apps::DomainsController < Projects::Apps::BaseController
  before_action :set_domain, only: %i[destroy make_default]

  def index
    @domains = @app.domains.kept
  end

  def new
    @domain = @app.domains.new
  end

  def create
    @domain = @app.domains.new(domain_params)

    if @domain.save
      ServerAction::CreateDomain.run_later!(@domain)
      redirect_to project_app_domains_path(@project, @app), notice: "Domain added successfully."
    else
      render turbo_stream: turbo_stream.replace(
        "domain_form",
        partial: "projects/apps/domains/form",
        locals: {
          project: @project,
          app: @app,
          domain: @domain
        }
      )
    end
  end

  def make_default
    @domain.make_default!
    redirect_to project_app_domains_path(@project, @app), notice: "Domain set as default."
  end

  def destroy
    @domain.discard
    ServerAction::DestroyDomain.run_later!(@domain)
    redirect_to project_app_domains_path(@project, @app), notice: "Domain removed successfully."
  end

  private

  def set_domain
    @domain = @app.domains.kept.find(params[:id])
  end

  def domain_params
    params.require(:domain).permit(:hostname)
  end
end
