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
      ServerActions::CreateDomain.run_later!(@app.server, @domain)
      render turbo_stream: [
        stream_toast("Domain added"),
        turbo_stream.replace("domains", partial: "projects/apps/domains/domains", locals: {app: @app})
      ]
    else
      render turbo_stream: turbo_stream.replace(
        "domain_form",
        partial: "projects/apps/domains/form",
        locals: {domain: @domain}
      )
    end
  end

  def make_default
    @domain.make_default!
    render turbo_stream: [
      turbo_stream.replace("domains", partial: "projects/apps/domains/domains", locals: {app: @app}),
      stream_toast("Domain set as default")
    ]
  end

  def destroy
    Domain::DestroyDomain.new(@domain).destroy
    render turbo_stream: [
      stream_toast("Domain deleted"),
      turbo_stream.remove(@domain)
    ]
  end

  private

  def set_domain
    @domain = @app.domains.kept.find(params[:id])
  end

  def domain_params
    params.require(:domain).permit(:hostname)
  end
end
