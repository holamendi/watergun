class ServerActions::ImportDokkuProject < ServerAction
  SLUG = "dokku.import"

  SERVICE_PLUGIN_NAMES = (Dokku::Plugin::InstallCommand::PLUGINS.keys.map(&:to_s) - ["letsencrypt"]).freeze
  KNOWN_NON_SERVICE_PLUGIN_NAMES = %w[
    apps builder certs checks common config domains git letsencrypt logs network nginx plugin proxy ps repo
    scheduler-docker shell ssh-keys storage tar trace
  ].freeze
  WATERGUN_DOKKU_ID_PATTERN = /\Awatergun(?:-|$)/

  RemoteState = Data.define(:apps, :services)
  RemoteApp = Data.define(:dokku_id, :builder, :domains, :ssl_enabled, :env_variables)
  RemoteService = Data.define(:dokku_id, :service_type, :data, :linked_apps)

  actionable Project

  store_attribute :payload, :include_watergun, :boolean, default: false
  store_attribute :payload, :summary, :json, default: {}
  store_attribute :payload, :skipped, :json, default: []

  validates :include_watergun, inclusion: {in: [true, false]}

  before_validation on: :create do
    self.account ||= project.account
    self.server ||= project.server
  end

  def concurrency_key
    server
  end

  private

  def run
    @skipped_entries = []
    imported = {}

    remote_state = discover_remote_state

    ApplicationRecord.transaction do
      imported = import_remote_state(remote_state)
    end

    self.summary = {
      apps: imported.fetch(:apps).size,
      domains: imported.fetch(:domains).size,
      env_variables: imported.fetch(:env_variables).size,
      services: imported.fetch(:services).size,
      service_links: imported.fetch(:service_links).size,
      skipped: @skipped_entries.size
    }
    self.skipped = @skipped_entries
    save!
  end

  def discover_remote_state
    RemoteState.new(
      apps: discover_apps,
      services: discover_services
    )
  end

  def discover_apps
    execute!(Dokku::Apps::ListCommand.new).parsed_output.filter_map do |dokku_id|
      if watergun_resource?(dokku_id)
        skip!(:app, dokku_id, "watergun resource")
        next
      end

      domain_report = execute!(Dokku::Domains::ReportCommand.new(app: dokku_id)).parsed_output
      cert_report = execute!(Dokku::Certs::ReportCommand.new(app: dokku_id)).parsed_output
      builder_report = execute!(Dokku::Builder::ReportCommand.new(app: dokku_id)).parsed_output
      env_variables = normalize_env_variables(
        execute!(Dokku::Config::ExportCommand.new(app: dokku_id)).parsed_output,
        owner_type: :app,
        owner_id: dokku_id
      )

      RemoteApp.new(
        dokku_id:,
        builder: normalize_builder(builder_report, dokku_id),
        domains: domain_report&.domains_app_vhosts || [],
        ssl_enabled: cert_report&.ssl_enabled || false,
        env_variables:
      )
    end
  end

  def discover_services
    plugins = execute!(Dokku::Plugin::ListCommand.new).parsed_output.select(&:enabled)
    plugin_names = plugins.map(&:name)

    unsupported_plugin_names(plugin_names).each do |plugin_name|
      skip!(:plugin, plugin_name, "unsupported service plugin")
    end

    SERVICE_PLUGIN_NAMES.filter_map do |service_type|
      next unless plugin_names.include?(service_type)

      execute!(Dokku::Services::ListCommand.new(plugin: service_type)).parsed_output.map do |dokku_id|
        if watergun_resource?(dokku_id)
          skip!(:service, "#{service_type}:#{dokku_id}", "watergun resource")
          next
        end

        info = execute!(Dokku::Services::InfoCommand.new(plugin: service_type, service: dokku_id)).parsed_output || {}
        linked_apps = execute!(Dokku::Services::LinksCommand.new(plugin: service_type, service: dokku_id)).parsed_output

        RemoteService.new(
          dokku_id:,
          service_type:,
          data: {
            dsn: info[:dsn],
            version: info[:version]
          }.compact,
          linked_apps:
        )
      end
    end.flatten.compact
  end

  def import_remote_state(remote_state)
    now = Time.current
    imported = {
      apps: [],
      domains: [],
      env_variables: [],
      services: [],
      service_links: []
    }

    apps_by_dokku_id = import_apps(remote_state.apps, now, imported)
    services_by_dokku_id = import_services(remote_state.services, now, imported)
    import_service_links(remote_state.services, apps_by_dokku_id, services_by_dokku_id, now, imported)
    discard_stale_records(imported)

    imported
  end

  def import_apps(remote_apps, now, imported)
    remote_apps.each_with_object({}) do |remote_app, apps_by_dokku_id|
      if managed_app_conflict?(remote_app.dokku_id)
        skip!(:app, remote_app.dokku_id, "dokku id is already managed by another project")
        next
      end

      app = find_or_initialize_app(remote_app.dokku_id)
      app.name = display_name(remote_app.dokku_id) if app.new_record? || app.name.blank?
      app.assign_attributes(
        account: project.account,
        server: project.server,
        builder: remote_app.builder,
        status: :active,
        deployed_at: now
      )
      app.save!

      imported[:apps] << app.id
      apps_by_dokku_id[remote_app.dokku_id] = app
      imported[:domains].concat(sync_domains(app, remote_app, now))
      imported[:env_variables].concat(sync_env_variables(app, remote_app, now))
    end
  end

  def import_services(remote_services, now, imported)
    seen_dokku_ids = {}

    remote_services.each_with_object({}) do |remote_service, services_by_dokku_id|
      if seen_dokku_ids.key?(remote_service.dokku_id)
        skip!(:service, "#{remote_service.service_type}:#{remote_service.dokku_id}", "dokku id was already imported for #{seen_dokku_ids.fetch(remote_service.dokku_id)}")
        next
      end

      if managed_service_conflict?(remote_service.dokku_id)
        skip!(:service, "#{remote_service.service_type}:#{remote_service.dokku_id}", "dokku id is already managed by another project")
        next
      end

      service = find_or_initialize_service(remote_service.dokku_id)
      service.name = display_name(remote_service.dokku_id) if service.new_record? || service.name.blank?
      service.assign_attributes(
        account: project.account,
        server: project.server,
        service_type: remote_service.service_type,
        status: :active,
        deployed_at: now
      )
      service.dsn = remote_service.data[:dsn]
      service.version = remote_service.data[:version]
      service.save!

      imported[:services] << service.id
      services_by_dokku_id[[remote_service.service_type, remote_service.dokku_id]] = service
      seen_dokku_ids[remote_service.dokku_id] = remote_service.service_type
    end
  end

  def import_service_links(remote_services, apps_by_dokku_id, services_by_dokku_id, now, imported)
    remote_services.each do |remote_service|
      service = services_by_dokku_id[[remote_service.service_type, remote_service.dokku_id]]
      next unless service

      remote_service.linked_apps.each do |linked_app_dokku_id|
        app = apps_by_dokku_id[linked_app_dokku_id]

        unless app
          skip!(:service_link, "#{remote_service.service_type}:#{remote_service.dokku_id}->#{linked_app_dokku_id}", "linked app was not imported")
          next
        end

        env_variable = matching_service_env_variable(app, service)
        unless env_variable
          skip!(:service_link, "#{remote_service.service_type}:#{remote_service.dokku_id}->#{linked_app_dokku_id}", "could not confidently match an env variable")
          next
        end

        env_variable.update!(internal: true, status: :synced, synced_at: now)

        service_link = find_or_initialize_service_link(service, app)
        service_link.assign_attributes(
          account: project.account,
          env_variable:,
          status: :active
        )
        service_link.save!

        imported[:service_links] << service_link.id
      end
    end
  end

  def sync_domains(app, remote_app, _now)
    imported_domain_ids = []
    app.domains.kept.update_all(is_default: false)

    remote_app.domains.each_with_index do |hostname, index|
      domain = find_or_initialize_domain(app, hostname)
      domain.assign_attributes(
        account: app.account,
        ssl_enabled: remote_app.ssl_enabled,
        is_default: index.zero?,
        status: :active
      )
      domain.save!
      imported_domain_ids << domain.id
    end

    stale_domains = imported_domain_ids.any? ? app.domains.kept.where.not(id: imported_domain_ids) : app.domains.kept
    stale_domains.find_each(&:discard)

    imported_domain_ids
  end

  def sync_env_variables(app, remote_app, now)
    imported_env_variable_ids = []

    remote_app.env_variables.each do |env_attributes|
      env_variable = find_or_initialize_env_variable(app, env_attributes.fetch(:name))
      env_variable.assign_attributes(
        account: app.account,
        value: env_attributes.fetch(:value),
        internal: false,
        status: :synced,
        synced_at: now
      )

      if env_variable.valid?
        env_variable.save!
        imported_env_variable_ids << env_variable.id
      else
        skip!(:env_variable, "#{app.dokku_id}:#{env_attributes.fetch(:name)}", env_variable.errors.full_messages.to_sentence)
      end
    end

    stale_env_variables = imported_env_variable_ids.any? ? app.env_variables.kept.where.not(id: imported_env_variable_ids) : app.env_variables.kept
    stale_env_variables.find_each(&:discard)

    imported_env_variable_ids
  end

  def discard_stale_records(imported)
    discard_stale(project.service_links.kept, imported[:service_links])
    discard_stale_apps(imported[:apps])
    discard_stale(project.services.kept, imported[:services])
  end

  def discard_stale(scope, imported_ids)
    stale_scope = imported_ids.any? ? scope.where.not(id: imported_ids) : scope
    stale_scope.find_each(&:discard)
  end

  def discard_stale_apps(imported_app_ids)
    stale_apps = imported_app_ids.any? ? project.apps.kept.where.not(id: imported_app_ids) : project.apps.kept

    stale_apps.find_each do |app|
      app.domains.kept.find_each(&:discard)
      app.env_variables.kept.find_each(&:discard)
      app.discard
    end
  end

  def matching_service_env_variable(app, service)
    return if service.dsn.blank?

    matches = app.env_variables.kept.select { |env_variable| env_variable.value == service.dsn }
    return unless matches.one?

    matches.first
  end

  def managed_app_conflict?(dokku_id)
    server.apps.kept.where(dokku_id:).where.not(project_id: project.id).exists?
  end

  def managed_service_conflict?(dokku_id)
    server.services.kept.where(dokku_id:).where.not(project_id: project.id).exists?
  end

  def find_or_initialize_app(dokku_id)
    project.apps.with_discarded.find_or_initialize_by(dokku_id:).tap do |app|
      app.undiscard if app.discarded?
    end
  end

  def find_or_initialize_service(dokku_id)
    project.services.with_discarded.find_or_initialize_by(dokku_id:).tap do |service|
      service.undiscard if service.discarded?
    end
  end

  def find_or_initialize_domain(app, hostname)
    app.domains.with_discarded.find_or_initialize_by(hostname:).tap do |domain|
      domain.undiscard if domain.discarded?
    end
  end

  def find_or_initialize_env_variable(app, name)
    app.env_variables.with_discarded.find_or_initialize_by(name:).tap do |env_variable|
      env_variable.undiscard if env_variable.discarded?
    end
  end

  def find_or_initialize_service_link(service, app)
    ServiceLink.with_discarded.find_or_initialize_by(service:, app:).tap do |service_link|
      service_link.undiscard if service_link.discarded?
    end
  end

  def normalize_env_variables(env_variables, owner_type:, owner_id:)
    Array(env_variables).filter_map do |env_variable|
      name = env_variable["name"] || env_variable[:name] || env_variable["key"] || env_variable[:key]
      value = env_variable["value"] || env_variable[:value]

      if name.blank? || value.nil?
        skip!(:env_variable, "#{owner_type}:#{owner_id}", "invalid config export entry")
        next
      end

      {name:, value:}
    end
  end

  def normalize_builder(builder_report, dokku_id)
    builder = builder_report&.selected.presence || builder_report&.computed_selected.presence
    builder = builder&.delete_prefix("builder-")
    return "herokuish" if builder.blank?
    return builder if App.builders.key?(builder)

    skip!(:app, dokku_id, "unsupported builder #{builder.inspect}; defaulted to herokuish")
    "herokuish"
  end

  def unsupported_plugin_names(plugin_names)
    plugin_names - SERVICE_PLUGIN_NAMES - KNOWN_NON_SERVICE_PLUGIN_NAMES
  end

  def watergun_resource?(dokku_id)
    !include_watergun && dokku_id.match?(WATERGUN_DOKKU_ID_PATTERN)
  end

  def display_name(dokku_id)
    dokku_id.tr("_-", " ").squish.titleize
  end

  def skip!(type, identifier, reason)
    @skipped_entries << {
      type: type.to_s,
      identifier: identifier.to_s,
      reason:
    }
  end
end
