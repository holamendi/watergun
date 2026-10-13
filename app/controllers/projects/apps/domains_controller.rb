class Projects::Apps::DomainsController < Projects::Apps::BaseController
  before_action :set_domain, only: %i[destroy make_default]

  def index
    @domains = domains_scope
  end

  def new
    @domain = @app.domains.new
  end

  def create
    @domain = @app.domains.new(domain_params)

    if @domain.save
      ServerAction::Enqueue.call(action: ServerActions::CreateDomain, target: @domain)
      render turbo_stream: [
        stream_toast("Domain added"),
        stream_domains,
        turbo_stream.action(:close_dialog, helpers.dom_id(@app, :domain_modal))
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
      stream_domains,
      stream_toast("Domain set as default")
    ]
  end

  def destroy
    Domain::DestroyDomain.new(@domain).destroy
    render turbo_stream: [
      stream_toast("Domain deleted"),
      stream_domains
    ]
  end

  private

  def set_domain
    @domain = @app.domains.kept.find(params[:id])
  end

  def domain_params
    params.require(:domain).permit(:hostname)
  end

  def domains_scope
    @app.domains.kept
  end

  def stream_domains
    turbo_stream.replace(
      "domains",
      partial: "projects/apps/domains/domains",
      locals: {
        project: @project,
        app: @app,
        domains: domains_scope,
        modal_id: helpers.dom_id(@app, :domain_modal)
      }
    )
  end
end
