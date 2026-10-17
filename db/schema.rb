# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "api_token_audits", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.bigint "api_token_id", null: false
    t.string "action", null: false
    t.string "request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_api_token_audits_on_account_id"
    t.index ["api_token_id"], name: "index_api_token_audits_on_api_token_id"
    t.index ["user_id"], name: "index_api_token_audits_on_user_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "name"
    t.boolean "read_only", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "token_digest", null: false
    t.bigint "user_id"
    t.jsonb "scopes", default: ["apps:read"], null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.index ["account_id"], name: "index_api_tokens_on_account_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "apps", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "builder"
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.string "deploy_token"
    t.datetime "deployed_at"
    t.datetime "discarded_at"
    t.string "dokku_id", null: false
    t.string "name", null: false
    t.boolean "pending_restart", default: false, null: false
    t.integer "project_id"
    t.integer "server_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_apps_on_account_id"
    t.index ["deploy_token"], name: "index_apps_on_deploy_token", unique: true
    t.index ["discarded_at"], name: "index_apps_on_discarded_at"
    t.index ["project_id"], name: "index_apps_on_project_id"
    t.index ["server_id"], name: "index_apps_on_server_id"
  end

  create_table "command_runs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "command"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_command_runs_on_account_id"
    t.index ["app_id"], name: "index_command_runs_on_app_id"
  end

  create_table "container_checks", force: :cascade do |t|
    t.integer "account_id", null: false
    t.bigint "block_io_read_bytes"
    t.bigint "block_io_write_bytes"
    t.integer "container_id", null: false
    t.float "cpu_percentage", null: false
    t.bigint "memory_limit_bytes"
    t.float "memory_percentage", null: false
    t.bigint "memory_used_bytes"
    t.bigint "network_io_in_bytes"
    t.bigint "network_io_out_bytes"
    t.datetime "timestamp", null: false
    t.index ["account_id"], name: "index_container_checks_on_account_id"
    t.index ["container_id", "timestamp"], name: "index_container_checks_on_container_id_and_timestamp"
    t.index ["container_id"], name: "index_container_checks_on_container_id"
    t.index ["timestamp"], name: "index_container_checks_on_timestamp"
  end

  create_table "containers", force: :cascade do |t|
    t.integer "account_id", null: false
    t.bigint "block_io_read_bytes"
    t.bigint "block_io_write_bytes"
    t.datetime "checked_at", null: false
    t.string "cid", null: false
    t.integer "containerizable_id", null: false
    t.string "containerizable_type", null: false
    t.float "cpu_percentage", null: false
    t.datetime "created_at", null: false
    t.bigint "memory_limit_bytes"
    t.float "memory_percentage", null: false
    t.bigint "memory_used_bytes"
    t.string "name", null: false
    t.bigint "network_io_in_bytes"
    t.bigint "network_io_out_bytes"
    t.integer "server_id", null: false
    t.string "status"
    t.datetime "stopped_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_containers_on_account_id"
    t.index ["cid"], name: "index_containers_on_cid"
    t.index ["containerizable_type", "containerizable_id"], name: "index_containers_on_containerizable"
    t.index ["server_id"], name: "index_containers_on_server_id"
    t.index ["status"], name: "index_containers_on_status"
  end

  create_table "deployments", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}
    t.datetime "finished_at"
    t.integer "github_event_id"
    t.string "repo", null: false
    t.string "sha"
    t.string "source"
    t.datetime "started_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["account_id"], name: "index_deployments_on_account_id"
    t.index ["app_id"], name: "index_deployments_on_app_id"
    t.index ["github_event_id"], name: "index_deployments_on_github_event_id"
    t.index ["status"], name: "index_deployments_on_status"
    t.index ["user_id"], name: "index_deployments_on_user_id"
  end

  create_table "domains", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "hostname", null: false
    t.boolean "is_default", default: false, null: false
    t.boolean "ssl_enabled", default: false, null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_domains_on_account_id"
    t.index ["app_id", "is_default"], name: "index_domains_on_app_id_and_is_default", unique: true, where: "((discarded_at IS NULL) AND (is_default = true))"
    t.index ["app_id"], name: "index_domains_on_app_id"
    t.index ["discarded_at"], name: "index_domains_on_discarded_at"
    t.index ["status"], name: "index_domains_on_status"
  end

  create_table "env_variables", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.boolean "internal", default: false
    t.string "name", null: false
    t.string "status", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["account_id"], name: "index_env_variables_on_account_id"
    t.index ["app_id", "name"], name: "index_env_variables_on_app_id_and_name", unique: true, where: "(discarded_at IS NULL)"
    t.index ["app_id"], name: "index_env_variables_on_app_id"
    t.index ["discarded_at"], name: "index_env_variables_on_discarded_at"
  end

  create_table "github_apps", force: :cascade do |t|
    t.integer "account_id"
    t.integer "app_id", null: false
    t.string "client_id", null: false
    t.string "client_secret", null: false
    t.datetime "created_at", null: false
    t.json "events", null: false
    t.string "html_url", null: false
    t.string "name", null: false
    t.string "pem", null: false
    t.json "permissions", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret", null: false
    t.index ["account_id"], name: "index_github_apps_on_account_id"
  end

  create_table "github_events", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "github_installation_id", null: false
    t.json "headers"
    t.json "payload"
    t.datetime "processed_at"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_github_events_on_account_id"
    t.index ["github_installation_id"], name: "index_github_events_on_github_installation_id"
  end

  create_table "github_installation_access_tokens", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "github_installation_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_github_installation_access_tokens_on_account_id"
    t.index ["github_installation_id"], name: "idx_on_github_installation_id_02fb0b0bcf"
  end

  create_table "github_installations", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "github_app_id", null: false
    t.integer "installation_id"
    t.string "login"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_github_installations_on_account_id"
    t.index ["github_app_id"], name: "index_github_installations_on_github_app_id"
  end

  create_table "github_repos", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "branch", null: false
    t.datetime "created_at", null: false
    t.boolean "private", default: false, null: false
    t.string "repo", null: false
    t.datetime "updated_at", null: false
    t.boolean "webhook_deploy", default: false
    t.index ["account_id"], name: "index_github_repos_on_account_id"
    t.index ["app_id", "repo"], name: "index_github_repos_on_app_id_and_repo", unique: true
    t.index ["app_id"], name: "index_github_repos_on_app_id"
  end

  create_table "log_streams", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_ping_at"
    t.integer "log_streamable_id", null: false
    t.string "log_streamable_type", null: false
    t.integer "server_id", null: false
    t.datetime "streaming_at"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["account_id"], name: "index_log_streams_on_account_id"
    t.index ["log_streamable_type", "log_streamable_id"], name: "index_log_streams_on_log_streamable"
    t.index ["server_id"], name: "index_log_streams_on_server_id"
    t.index ["uuid"], name: "index_log_streams_on_uuid", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["user_id", "account_id"], name: "index_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name"
    t.integer "server_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_projects_on_account_id"
    t.index ["discarded_at"], name: "index_projects_on_discarded_at"
    t.index ["server_id"], name: "index_projects_on_server_id"
  end

  create_table "server_action_logs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "server_action_run_id", null: false
    t.json "ssh_commands", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_server_action_logs_on_account_id"
    t.index ["id", "server_action_run_id"], name: "index_server_action_logs_on_id_and_server_action_run_id", unique: true
    t.index ["server_action_run_id"], name: "index_server_action_logs_on_server_action_run_id"
  end

  create_table "server_action_runs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "target_id"
    t.string "target_type"
    t.datetime "created_at", null: false
    t.string "failure_message"
    t.datetime "finished_at"
    t.datetime "running_at"
    t.integer "server_id", null: false
    t.string "source", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.text "payload"
    t.string "action_key", null: false
    t.string "resource_key", null: false
    t.datetime "enqueued_at"
    t.datetime "scheduling_failed_at"
    t.index ["account_id"], name: "index_server_action_runs_on_account_id"
    t.index ["server_id"], name: "index_server_action_runs_on_server_id"
    t.index ["status"], name: "index_server_action_runs_on_status"
    t.index ["target_type", "target_id"], name: "index_server_action_runs_on_target"
    t.index ["user_id"], name: "index_server_action_runs_on_user_id"
  end

  create_table "server_checks", force: :cascade do |t|
    t.integer "account_id", null: false
    t.float "cpu_usage", null: false
    t.datetime "created_at", null: false
    t.bigint "disk_total_bytes"
    t.float "disk_usage"
    t.bigint "disk_used_bytes"
    t.float "load_average"
    t.bigint "memory_total_bytes"
    t.float "memory_usage", null: false
    t.bigint "memory_used_bytes"
    t.integer "server_id", null: false
    t.datetime "timestamp", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_server_checks_on_account_id"
    t.index ["server_id", "timestamp"], name: "index_server_checks_on_server_id_and_timestamp"
    t.index ["server_id"], name: "index_server_checks_on_server_id"
    t.index ["timestamp"], name: "index_server_checks_on_timestamp"
  end

  create_table "servers", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "cpu_type"
    t.datetime "created_at", null: false
    t.json "data", default: {}
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "public_ip"
    t.integer "ssh_port", default: 22
    t.string "ssh_user", default: "dokku", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_servers_on_account_id"
    t.index ["last_synced_at"], name: "index_servers_on_last_synced_at"
    t.index ["status"], name: "index_servers_on_status"
  end

  create_table "service_links", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "env_variable_id", null: false
    t.integer "service_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_service_links_on_account_id"
    t.index ["app_id"], name: "index_service_links_on_app_id"
    t.index ["discarded_at"], name: "index_service_links_on_discarded_at"
    t.index ["env_variable_id"], name: "index_service_links_on_env_variable_id"
    t.index ["service_id", "app_id"], name: "index_service_links_on_service_id_and_app_id", unique: true
    t.index ["service_id"], name: "index_service_links_on_service_id"
    t.index ["status"], name: "index_service_links_on_status"
  end

  create_table "services", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "deployed_at"
    t.datetime "discarded_at"
    t.string "dokku_id"
    t.string "name", null: false
    t.integer "project_id", null: false
    t.integer "server_id", null: false
    t.string "service_type"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_services_on_account_id"
    t.index ["project_id"], name: "index_services_on_project_id"
    t.index ["server_id"], name: "index_services_on_server_id"
    t.index ["service_type"], name: "index_services_on_service_type"
    t.index ["status"], name: "index_services_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "ssh_keys", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.text "private_key", null: false
    t.integer "server_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ssh_keys_on_account_id"
    t.index ["id", "server_id"], name: "index_ssh_keys_on_id_and_server_id", unique: true
    t.index ["server_id"], name: "index_ssh_keys_on_server_id"
  end

  create_table "storage_mounts", force: :cascade do |t|
    t.integer "account_id"
    t.integer "app_id"
    t.string "chown"
    t.string "container_path", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "host_path", null: false
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_storage_mounts_on_account_id"
    t.index ["app_id", "container_path"], name: "index_storage_mounts_on_app_id_and_container_path", unique: true
    t.index ["app_id"], name: "index_storage_mounts_on_app_id"
    t.index ["discarded_at"], name: "index_storage_mounts_on_discarded_at"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "api_token_audits", "accounts"
  add_foreign_key "api_token_audits", "api_tokens"
  add_foreign_key "api_token_audits", "users"
  add_foreign_key "api_tokens", "accounts"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "apps", "accounts"
  add_foreign_key "apps", "projects"
  add_foreign_key "apps", "servers"
  add_foreign_key "command_runs", "accounts"
  add_foreign_key "command_runs", "apps"
  add_foreign_key "container_checks", "accounts"
  add_foreign_key "container_checks", "containers"
  add_foreign_key "containers", "accounts"
  add_foreign_key "containers", "servers"
  add_foreign_key "deployments", "accounts"
  add_foreign_key "deployments", "apps"
  add_foreign_key "deployments", "github_events"
  add_foreign_key "deployments", "users"
  add_foreign_key "domains", "accounts"
  add_foreign_key "domains", "apps"
  add_foreign_key "env_variables", "accounts"
  add_foreign_key "env_variables", "apps"
  add_foreign_key "github_apps", "accounts"
  add_foreign_key "github_events", "accounts"
  add_foreign_key "github_installation_access_tokens", "accounts"
  add_foreign_key "github_installation_access_tokens", "github_installations"
  add_foreign_key "github_installations", "accounts"
  add_foreign_key "github_installations", "github_apps"
  add_foreign_key "github_repos", "accounts"
  add_foreign_key "github_repos", "apps"
  add_foreign_key "log_streams", "accounts"
  add_foreign_key "log_streams", "servers"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "accounts"
  add_foreign_key "projects", "servers"
  add_foreign_key "server_action_logs", "accounts"
  add_foreign_key "server_action_logs", "server_action_runs"
  add_foreign_key "server_action_runs", "accounts"
  add_foreign_key "server_action_runs", "servers"
  add_foreign_key "server_action_runs", "users"
  add_foreign_key "server_checks", "accounts"
  add_foreign_key "server_checks", "servers"
  add_foreign_key "servers", "accounts"
  add_foreign_key "service_links", "accounts"
  add_foreign_key "service_links", "apps"
  add_foreign_key "service_links", "env_variables"
  add_foreign_key "service_links", "services"
  add_foreign_key "services", "accounts"
  add_foreign_key "services", "projects"
  add_foreign_key "services", "servers"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "ssh_keys", "accounts"
  add_foreign_key "ssh_keys", "servers"
end
