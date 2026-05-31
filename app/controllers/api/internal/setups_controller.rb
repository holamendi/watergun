class Api::Internal::SetupsController < ActionController::API
  def create
    unless setup_token_is_valid?
      return render json: {error: "Invalid setup token"}, status: :unauthorized
    end

    if Account.any?
      return render json: {error: "An account already exists"}, status: :unprocessable_content
    end

    begin
      ApplicationRecord.transaction do
        create_account!
        create_server!
        create_user!
        create_installation! if installation_requested?
      end
    rescue => e
      return render json: {error: e.message}, status: :unprocessable_content
    end

    render json: {
      first_run_url: pretty_first_run_url(signed_id: first_run_token),
      public_key: @server.ssh_key.public_key
    }
  end

  private

  def bearer_token
    ActionController::HttpAuthentication::Token.token_and_options(request).first
  end

  def setup_token_is_valid?
    setup_token.present? && ActiveSupport::SecurityUtils.secure_compare(setup_token, bearer_token)
  end

  def create_account!
    @account = Account.create!(name: "Default")
  end

  def create_server!
    @server = @account.servers.create!(server_params)
  end

  def create_user!
    @user = User.create!(user_params.merge(password: SecureRandom.alphanumeric(16)))
    @user.memberships.create!(account: @account)
  end

  def create_installation!
    create_project!
    create_app!
    create_domain!
    create_service!
    create_service_link!
  end

  def create_project!
    @project = @account.projects.create!(
      server: @server,
      name: installation_project_params.fetch(:name)
    )
  end

  def create_app!
    @app = @project.apps.create!(
      server: @server,
      name: installation_app_params.fetch(:name),
      dokku_id: installation_app_params.fetch(:dokku_id),
      builder: installation_app_params.fetch(:builder),
      status: :active,
      deployed_at: Time.current
    )
  end

  def create_domain!
    @app.domains.create!(
      hostname: installation_domain_params.fetch(:hostname),
      ssl_enabled: installation_domain_params.fetch(:ssl_enabled),
      is_default: true,
      status: :active
    )
  end

  def create_service!
    @service = @project.services.create!(
      server: @server,
      name: installation_service_params.fetch(:name),
      dokku_id: installation_service_params.fetch(:dokku_id),
      service_type: installation_service_params.fetch(:service_type),
      status: :active,
      deployed_at: Time.current,
      data: {
        dsn: installation_service_params.fetch(:dsn),
        version: installation_service_params.fetch(:version)
      }
    )
  end

  def create_service_link!
    @env_variable = @app.env_variables.create!(
      name: installation_service_link_params.fetch(:env_name),
      value: installation_service_params.fetch(:dsn),
      internal: true,
      status: :synced,
      synced_at: Time.current
    )

    ServiceLink.create!(
      app: @app,
      service: @service,
      env_variable: @env_variable,
      status: :active
    )
  end

  def first_run_token
    @user.signed_id(purpose: :first_run)
  end

  def setup_token
    ENV.fetch("ACCOUNT_SETUP_TOKEN").presence
  end

  def server_params
    params.require(:server).permit(:name, :public_ip, :cpu_type)
  end

  def user_params
    params.require(:user).permit(:email)
  end

  def installation_requested?
    params[:installation].present?
  end

  def installation_params
    @installation_params ||= params.require(:installation).permit(
      project: [:name],
      app: [:name, :dokku_id, :builder],
      domain: [:hostname, :ssl_enabled],
      service: [:name, :dokku_id, :service_type, :version, :dsn],
      service_link: [:env_name]
    )
  end

  def installation_project_params
    installation_params.require(:project)
  end

  def installation_app_params
    installation_params.require(:app)
  end

  def installation_domain_params
    installation_params.require(:domain)
  end

  def installation_service_params
    installation_params.require(:service)
  end

  def installation_service_link_params
    installation_params.require(:service_link)
  end
end
