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

ActiveRecord::Schema[7.2].define(version: 2024_07_24_141020) do
  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "api_tokens", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "token", null: false
    t.boolean "read_only", default: false, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["account_id"], name: "index_api_tokens_on_account_id"
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
  end

  create_table "apps", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "name", null: false
    t.string "dokku_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.datetime "deployed_at"
    t.string "status"
    t.integer "project_id"
    t.boolean "pending_restart", default: false, null: false
    t.string "builder"
    t.index ["account_id"], name: "index_apps_on_account_id"
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
    t.integer "container_id", null: false
    t.datetime "timestamp", null: false
    t.float "cpu_percentage", null: false
    t.float "memory_percentage", null: false
    t.string "memory_usage", null: false
    t.string "block_io", null: false
    t.string "network_io", null: false
    t.index ["account_id"], name: "index_container_checks_on_account_id"
    t.index ["container_id"], name: "index_container_checks_on_container_id"
    t.index ["timestamp"], name: "index_container_checks_on_timestamp"
  end

  create_table "containers", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "containerizable_type", null: false
    t.integer "containerizable_id", null: false
    t.string "status"
    t.string "cid", null: false
    t.string "name", null: false
    t.float "cpu_percentage", null: false
    t.float "memory_percentage", null: false
    t.string "memory_usage", null: false
    t.string "block_io", null: false
    t.string "network_io", null: false
    t.datetime "last_synced_at", null: false
    t.datetime "stopped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_containers_on_account_id"
    t.index ["cid"], name: "index_containers_on_cid"
    t.index ["containerizable_type", "containerizable_id"], name: "index_containers_on_containerizable"
    t.index ["server_id"], name: "index_containers_on_server_id"
    t.index ["status"], name: "index_containers_on_status"
  end

  create_table "databases", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "name", null: false
    t.integer "status", null: false
    t.json "data", default: {}
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "project_id"
    t.integer "database_type", null: false
    t.index ["account_id"], name: "index_databases_on_account_id"
    t.index ["discarded_at"], name: "index_databases_on_discarded_at"
    t.index ["project_id"], name: "index_databases_on_project_id"
    t.index ["server_id"], name: "index_databases_on_server_id"
    t.index ["status"], name: "index_databases_on_status"
  end

  create_table "deployments", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "status"
    t.string "repo", null: false
    t.string "sha"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "started_at"
    t.json "data", default: {}
    t.integer "user_id"
    t.string "source"
    t.index ["account_id"], name: "index_deployments_on_account_id"
    t.index ["app_id"], name: "index_deployments_on_app_id"
    t.index ["status"], name: "index_deployments_on_status"
    t.index ["user_id"], name: "index_deployments_on_user_id"
  end

  create_table "domains", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "hostname", null: false
    t.string "status"
    t.boolean "ssl_enabled", default: false, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_default", default: false, null: false
    t.index ["account_id"], name: "index_domains_on_account_id"
    t.index ["app_id", "is_default"], name: "index_domains_on_app_id_and_is_default", unique: true, where: "discarded_at IS NULL AND is_default = true"
    t.index ["app_id"], name: "index_domains_on_app_id"
    t.index ["discarded_at"], name: "index_domains_on_discarded_at"
    t.index ["status"], name: "index_domains_on_status"
  end

  create_table "env_variables", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "name", null: false
    t.text "value", null: false
    t.string "status", null: false
    t.datetime "synced_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_env_variables_on_account_id"
    t.index ["app_id", "name"], name: "index_env_variables_on_app_id_and_name", unique: true, where: "discarded_at IS NULL"
    t.index ["app_id"], name: "index_env_variables_on_app_id"
    t.index ["discarded_at"], name: "index_env_variables_on_discarded_at"
  end

  create_table "github_access_tokens", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_github_access_tokens_on_account_id"
  end

  create_table "github_repos", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "app_id", null: false
    t.string "repo", null: false
    t.string "branch", null: false
    t.boolean "private", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_github_repos_on_account_id"
    t.index ["app_id", "repo"], name: "index_github_repos_on_app_id_and_repo", unique: true
    t.index ["app_id"], name: "index_github_repos_on_app_id"
  end

  create_table "log_streams", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "log_streamable_type", null: false
    t.integer "log_streamable_id", null: false
    t.string "uuid", null: false
    t.datetime "last_ping_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "streaming_at"
    t.index ["account_id"], name: "index_log_streams_on_account_id"
    t.index ["log_streamable_type", "log_streamable_id"], name: "index_log_streams_on_log_streamable"
    t.index ["server_id"], name: "index_log_streams_on_server_id"
    t.index ["uuid"], name: "index_log_streams_on_uuid", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["user_id", "account_id"], name: "index_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "name"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_projects_on_account_id"
    t.index ["discarded_at"], name: "index_projects_on_discarded_at"
    t.index ["server_id"], name: "index_projects_on_server_id"
  end

  create_table "server_action_logs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_action_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "ssh_commands", default: [], null: false
    t.index ["account_id"], name: "index_server_action_logs_on_account_id"
    t.index ["id", "server_action_id"], name: "index_server_action_logs_on_id_and_server_action_id", unique: true
    t.index ["server_action_id"], name: "index_server_action_logs_on_server_action_id"
  end

  create_table "server_actions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "actionable_type"
    t.integer "actionable_id"
    t.string "source", null: false
    t.string "status"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "running_at"
    t.json "payload", default: {}, null: false
    t.string "type"
    t.string "failure_message"
    t.integer "preceding_server_action_id"
    t.integer "user_id"
    t.index "json_extract(payload, '$.dokku_app_id')", name: "index_server_actions_on_dokku_app_id"
    t.index ["account_id"], name: "index_server_actions_on_account_id"
    t.index ["actionable_type", "actionable_id"], name: "index_server_events_on_actionable"
    t.index ["preceding_server_action_id"], name: "index_server_actions_on_preceding_server_action_id"
    t.index ["server_id"], name: "index_server_actions_on_server_id"
    t.index ["status"], name: "index_server_actions_on_status"
    t.index ["user_id"], name: "index_server_actions_on_user_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}
    t.integer "account_id", null: false
    t.datetime "last_synced_at"
    t.string "public_ip"
    t.string "cpu_type"
    t.index ["account_id"], name: "index_servers_on_account_id"
    t.index ["last_synced_at"], name: "index_servers_on_last_synced_at"
    t.index ["status"], name: "index_servers_on_status"
  end

  create_table "service_links", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "service_id", null: false
    t.integer "app_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["account_id"], name: "index_service_links_on_account_id"
    t.index ["app_id"], name: "index_service_links_on_app_id"
    t.index ["discarded_at"], name: "index_service_links_on_discarded_at"
    t.index ["service_id", "app_id"], name: "index_service_links_on_service_id_and_app_id", unique: true
    t.index ["service_id"], name: "index_service_links_on_service_id"
    t.index ["status"], name: "index_service_links_on_status"
  end

  create_table "services", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.string "service_type"
    t.string "name", null: false
    t.string "status"
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dokku_id"
    t.integer "project_id", null: false
    t.datetime "deployed_at"
    t.index ["account_id"], name: "index_services_on_account_id"
    t.index ["project_id"], name: "index_services_on_project_id"
    t.index ["server_id"], name: "index_services_on_server_id"
    t.index ["service_type"], name: "index_services_on_service_type"
    t.index ["status"], name: "index_services_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "ssh_keys", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "server_id", null: false
    t.text "private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ssh_keys_on_account_id"
    t.index ["id", "server_id"], name: "index_ssh_keys_on_id_and_server_id", unique: true
    t.index ["server_id"], name: "index_ssh_keys_on_server_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "api_tokens", "accounts"
  add_foreign_key "apps", "accounts"
  add_foreign_key "apps", "projects"
  add_foreign_key "apps", "servers"
  add_foreign_key "command_runs", "accounts"
  add_foreign_key "command_runs", "apps"
  add_foreign_key "container_checks", "accounts"
  add_foreign_key "container_checks", "containers"
  add_foreign_key "containers", "accounts"
  add_foreign_key "containers", "servers"
  add_foreign_key "databases", "accounts"
  add_foreign_key "databases", "projects"
  add_foreign_key "databases", "servers"
  add_foreign_key "deployments", "accounts"
  add_foreign_key "deployments", "apps"
  add_foreign_key "deployments", "users"
  add_foreign_key "domains", "accounts"
  add_foreign_key "domains", "apps"
  add_foreign_key "env_variables", "accounts"
  add_foreign_key "env_variables", "apps"
  add_foreign_key "github_access_tokens", "accounts"
  add_foreign_key "github_repos", "accounts"
  add_foreign_key "github_repos", "apps"
  add_foreign_key "log_streams", "accounts"
  add_foreign_key "log_streams", "servers"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "accounts"
  add_foreign_key "projects", "servers"
  add_foreign_key "server_action_logs", "accounts"
  add_foreign_key "server_action_logs", "server_actions"
  add_foreign_key "server_actions", "accounts"
  add_foreign_key "server_actions", "server_actions", column: "preceding_server_action_id"
  add_foreign_key "server_actions", "servers"
  add_foreign_key "server_actions", "users"
  add_foreign_key "servers", "accounts"
  add_foreign_key "service_links", "accounts"
  add_foreign_key "service_links", "apps"
  add_foreign_key "service_links", "services"
  add_foreign_key "services", "accounts"
  add_foreign_key "services", "projects"
  add_foreign_key "services", "servers"
  add_foreign_key "sessions", "users"
  add_foreign_key "ssh_keys", "accounts"
  add_foreign_key "ssh_keys", "servers"
end
