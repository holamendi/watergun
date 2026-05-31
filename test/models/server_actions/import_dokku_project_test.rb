require "test_helper"

class ServerActions::ImportDokkuProjectTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @account = accounts(:default)
    @server = @account.servers.create!(name: "import-server", public_ip: "127.0.0.2", cpu_type: "x86")
    @project = @account.projects.create!(server: @server, name: "Dokku Import", dokku_import: true)
  end

  test "imports apps domains env variables services and service links without scheduling mutating actions" do
    dsn = "postgres://blog-db:secret@dokku-postgres-blog-db:5432/blog-db"
    mock_import_session([
      apps_list("blog"),
      domains_report("blog", "blog.example.com"),
      certs_report("blog", ssl_enabled: true),
      builder_report("blog", selected: "dockerfile"),
      config_export("blog", [
        {name: "DATABASE_URL", value: dsn},
        {name: "RACK_ENV", value: "production"}
      ]),
      plugin_list("postgres"),
      services_list("postgres", "blog-db"),
      service_info("postgres", "blog-db", dsn:, version: "16"),
      service_links("postgres", "blog-db", "blog")
    ])

    assert_no_difference -> { ServerAction.where.not(type: "ServerActions::ImportDokkuProject").count } do
      @server_action = ServerActions::ImportDokkuProject.run_now!(@server, @project)
    end

    assert @server_action.success?

    app = @project.apps.find_by!(dokku_id: "blog")
    domain = app.domains.find_by!(hostname: "blog.example.com")
    service = @project.services.find_by!(dokku_id: "blog-db")
    database_url = app.env_variables.find_by!(name: "DATABASE_URL")
    rack_env = app.env_variables.find_by!(name: "RACK_ENV")
    service_link = ServiceLink.find_by!(app:, service:)

    assert_equal "Blog", app.name
    assert_equal "dockerfile", app.builder
    assert_equal "active", app.status
    assert_predicate app.deployed_at, :present?

    assert_equal "active", domain.status
    assert_predicate domain, :is_default?
    assert_predicate domain, :ssl_enabled?

    assert_equal dsn, database_url.value
    assert_predicate database_url, :internal?
    assert_equal "synced", database_url.status
    assert_predicate database_url.synced_at, :present?
    refute_predicate rack_env, :internal?

    assert_equal "Blog Db", service.name
    assert_equal "postgres", service.service_type
    assert_equal "active", service.status
    assert_equal dsn, service.dsn
    assert_equal "16", service.version
    assert_predicate service.deployed_at, :present?

    assert_equal "active", service_link.status
    assert_equal database_url, service_link.env_variable
    assert_equal 1, @server_action.reload.summary.fetch("apps")
    assert_empty @server_action.skipped
  end

  test "excludes watergun resources by default" do
    dsn = "postgres://customer-db:secret@dokku-postgres-customer-db:5432/customer-db"
    mock_import_session([
      apps_list("watergun", "customer"),
      domains_report("customer", "customer.example.com"),
      certs_report("customer", ssl_enabled: false),
      builder_report("customer", computed_selected: "herokuish"),
      config_export("customer", [{name: "DATABASE_URL", value: dsn}]),
      plugin_list("postgres"),
      services_list("postgres", "watergun-db", "customer-db"),
      service_info("postgres", "customer-db", dsn:, version: "16"),
      service_links("postgres", "customer-db", "customer")
    ])

    server_action = ServerActions::ImportDokkuProject.run_now!(@server, @project)

    assert server_action.success?
    assert_nil @project.apps.find_by(dokku_id: "watergun")
    assert_nil @project.services.find_by(dokku_id: "watergun-db")
    assert @project.apps.exists?(dokku_id: "customer")
    assert @project.services.exists?(dokku_id: "customer-db")
    assert_equal ["app", "service"], server_action.reload.skipped.map { |entry| entry.fetch("type") }
  end

  test "includes watergun resources when requested" do
    dsn = "postgres://watergun-db:secret@dokku-postgres-watergun-db:5432/watergun-db"
    mock_import_session([
      apps_list("watergun"),
      domains_report("watergun", "watergun.example.com"),
      certs_report("watergun", ssl_enabled: true),
      builder_report("watergun", selected: "dockerfile"),
      config_export("watergun", [{name: "DATABASE_URL", value: dsn}]),
      plugin_list("postgres"),
      services_list("postgres", "watergun-db"),
      service_info("postgres", "watergun-db", dsn:, version: "16"),
      service_links("postgres", "watergun-db", "watergun")
    ])

    server_action = ServerActions::ImportDokkuProject.run_now!(@server, @project, include_watergun: true)

    assert server_action.success?
    assert @project.apps.exists?(dokku_id: "watergun")
    assert @project.services.exists?(dokku_id: "watergun-db")
    assert_empty server_action.reload.skipped
  end

  test "skips unsupported plugins and ambiguous service links" do
    dsn = "postgres://blog-db:secret@dokku-postgres-blog-db:5432/blog-db"
    mock_import_session([
      apps_list("blog"),
      domains_report("blog", "blog.example.com"),
      certs_report("blog", ssl_enabled: false),
      builder_report("blog", computed_selected: "herokuish"),
      config_export("blog", [
        {name: "DATABASE_URL", value: dsn},
        {name: "DOKKU_DATABASE_BLUE_URL", value: dsn}
      ]),
      plugin_list("mailpit", "postgres"),
      services_list("postgres", "blog-db"),
      service_info("postgres", "blog-db", dsn:, version: "16"),
      service_links("postgres", "blog-db", "blog")
    ])

    server_action = ServerActions::ImportDokkuProject.run_now!(@server, @project)

    assert server_action.success?
    assert_empty ServiceLink.joins(:service).where(services: {project_id: @project.id})
    assert_equal ["plugin", "service_link"], server_action.reload.skipped.map { |entry| entry.fetch("type") }
  end

  test "re-running updates existing imported records without duplicates" do
    mock_import_session(basic_app_commands(env_value: "one"))
    ServerActions::ImportDokkuProject.run_now!(@server, @project)

    assert_equal 1, @project.apps.kept.count
    assert_equal 1, @project.apps.first.domains.kept.count
    assert_equal 1, @project.apps.first.env_variables.kept.count

    mock_import_session(basic_app_commands(env_value: "two"))

    assert_no_difference -> { @project.apps.count } do
      assert_no_difference -> { @project.apps.first.domains.count } do
        assert_no_difference -> { @project.apps.first.env_variables.count } do
          ServerActions::ImportDokkuProject.run_now!(@server, @project)
        end
      end
    end

    app = @project.reload.apps.find_by!(dokku_id: "blog")
    assert_equal "two", app.env_variables.find_by!(name: "FOO").value
  end

  test "discards stale imported records after successful discovery" do
    dsn = "postgres://blog-db:secret@dokku-postgres-blog-db:5432/blog-db"
    mock_import_session([
      apps_list("blog"),
      domains_report("blog", "blog.example.com"),
      certs_report("blog", ssl_enabled: false),
      builder_report("blog", computed_selected: "herokuish"),
      config_export("blog", [{name: "DATABASE_URL", value: dsn}]),
      plugin_list("postgres"),
      services_list("postgres", "blog-db"),
      service_info("postgres", "blog-db", dsn:, version: "16"),
      service_links("postgres", "blog-db", "blog")
    ])
    ServerActions::ImportDokkuProject.run_now!(@server, @project)

    app = @project.apps.find_by!(dokku_id: "blog")
    domain = app.domains.first
    env_variable = app.env_variables.first
    service = @project.services.find_by!(dokku_id: "blog-db")
    service_link = ServiceLink.find_by!(app:, service:)

    mock_import_session([
      apps_list,
      plugin_list("postgres"),
      services_list("postgres")
    ])
    ServerActions::ImportDokkuProject.run_now!(@server, @project)

    assert_predicate app.reload, :discarded?
    assert_predicate domain.reload, :discarded?
    assert_predicate env_variable.reload, :discarded?
    assert_predicate service.reload, :discarded?
    assert_predicate service_link.reload, :discarded?
  end

  private

  def mock_import_session(commands)
    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands:
    )
  end

  def basic_app_commands(env_value:)
    [
      apps_list("blog"),
      domains_report("blog", "blog.example.com"),
      certs_report("blog", ssl_enabled: false),
      builder_report("blog", computed_selected: "herokuish"),
      config_export("blog", [{name: "FOO", value: env_value}]),
      plugin_list
    ]
  end

  def apps_list(*apps)
    {cmd: "dokku apps:list", stdout: "=====> My Apps\n#{apps.join("\n")}\n"}
  end

  def domains_report(app, *domains)
    {
      cmd: "dokku domains:report #{app}",
      stdout: <<~OUTPUT
        =====> #{app} domains information
               Domains app enabled:           true
               Domains app vhosts:            #{domains.join(" ")}
               Domains global enabled:        true
               Domains global vhosts:         example.com
      OUTPUT
    }
  end

  def certs_report(app, ssl_enabled:)
    {
      cmd: "dokku certs:report #{app}",
      stdout: <<~OUTPUT
        =====> #{app} ssl information
               Ssl enabled: #{ssl_enabled}
      OUTPUT
    }
  end

  def builder_report(app, selected: nil, computed_selected: nil)
    {
      cmd: "dokku builder:report #{app}",
      stdout: <<~OUTPUT
        =====> #{app} builder information
               Builder computed selected: #{computed_selected}
               Builder selected:          #{selected}
      OUTPUT
    }
  end

  def config_export(app, env_variables)
    {
      cmd: "dokku config:export #{app} --format=json-list",
      stdout: env_variables.map { |env_variable| env_variable.stringify_keys }.to_json
    }
  end

  def plugin_list(*plugins)
    {
      cmd: "dokku plugin:list",
      stdout: plugins.map { |plugin| "#{plugin} 1.0.0 enabled" }.join("\n")
    }
  end

  def services_list(plugin, *services)
    {
      cmd: "dokku #{plugin}:list",
      stdout: "=====> #{plugin.titleize} services\n#{services.join("\n")}\n"
    }
  end

  def service_info(plugin, service, dsn:, version:)
    {
      cmd: "dokku #{plugin}:info #{service}",
      stdout: <<~OUTPUT
        Dsn:                 #{dsn}
        Version:             #{version}
      OUTPUT
    }
  end

  def service_links(plugin, service, *apps)
    {
      cmd: "dokku #{plugin}:links #{service}",
      stdout: apps.join("\n")
    }
  end
end
