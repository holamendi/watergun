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

ActiveRecord::Schema[7.1].define(version: 2024_04_22_095051) do
  create_table "apps", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "name", null: false
    t.string "dokku_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.datetime "last_deployed_at"
    t.json "urls", default: []
    t.string "status"
    t.index ["discarded_at"], name: "index_apps_on_discarded_at"
    t.index ["org_id"], name: "index_apps_on_org_id"
    t.index ["server_id"], name: "index_apps_on_server_id"
  end

  create_table "container_metrics", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "container_id", null: false
    t.datetime "timestamp", null: false
    t.float "cpu_percentage", null: false
    t.float "memory_percentage", null: false
    t.string "memory_usage", null: false
    t.string "block_io", null: false
    t.string "network_io", null: false
    t.index ["container_id"], name: "index_container_metrics_on_container_id"
    t.index ["org_id"], name: "index_container_metrics_on_org_id"
    t.index ["timestamp"], name: "index_container_metrics_on_timestamp"
  end

  create_table "containers", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "containerizable_type", null: false
    t.integer "containerizable_id", null: false
    t.string "status", null: false
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
    t.index ["cid"], name: "index_containers_on_cid"
    t.index ["containerizable_type", "containerizable_id"], name: "index_containers_on_containerizable"
    t.index ["org_id"], name: "index_containers_on_org_id"
    t.index ["server_id"], name: "index_containers_on_server_id"
    t.index ["status"], name: "index_containers_on_status"
  end

  create_table "environment_configurations", force: :cascade do |t|
    t.integer "org_id", null: false
    t.string "environment_configurable_type", null: false
    t.integer "environment_configurable_id", null: false
    t.json "variables", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment_configurable_type", "environment_configurable_id"], name: "index_environment_configurations_on_environment_configurable"
    t.index ["org_id"], name: "index_environment_configurations_on_org_id"
  end

  create_table "github_access_tokens", force: :cascade do |t|
    t.integer "org_id", null: false
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_github_access_tokens_on_org_id"
  end

  create_table "github_repos", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "app_id", null: false
    t.string "repo", null: false
    t.string "branch", null: false
    t.boolean "private", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id", "repo"], name: "index_github_repos_on_app_id_and_repo", unique: true
    t.index ["app_id"], name: "index_github_repos_on_app_id"
    t.index ["org_id"], name: "index_github_repos_on_org_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "org_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_memberships_on_org_id"
    t.index ["user_id", "org_id"], name: "index_memberships_on_user_id_and_org_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "orgs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "server_action_logs", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_action_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "ssh_commands", default: [], null: false
    t.index ["id", "server_action_id"], name: "index_server_action_logs_on_id_and_server_action_id", unique: true
    t.index ["org_id"], name: "index_server_action_logs_on_org_id"
    t.index ["server_action_id"], name: "index_server_action_logs_on_server_action_id"
  end

  create_table "server_actions", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "actionable_type"
    t.integer "actionable_id"
    t.integer "membership_id"
    t.string "source", null: false
    t.string "status", null: false
    t.string "job_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "running_at"
    t.json "payload", default: {}, null: false
    t.string "type"
    t.index ["actionable_type", "actionable_id"], name: "index_server_events_on_actionable"
    t.index ["membership_id"], name: "index_server_actions_on_membership_id"
    t.index ["org_id"], name: "index_server_actions_on_org_id"
    t.index ["server_id"], name: "index_server_actions_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}
    t.integer "org_id", null: false
    t.datetime "last_synced_at"
    t.string "public_ip"
    t.string "cpu_type"
    t.index ["last_synced_at"], name: "index_servers_on_last_synced_at"
    t.index ["org_id"], name: "index_servers_on_org_id"
  end

  create_table "service_links", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "service_id", null: false
    t.integer "app_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["app_id"], name: "index_service_links_on_app_id"
    t.index ["discarded_at"], name: "index_service_links_on_discarded_at"
    t.index ["org_id"], name: "index_service_links_on_org_id"
    t.index ["service_id", "app_id"], name: "index_service_links_on_service_id_and_app_id", unique: true
    t.index ["service_id"], name: "index_service_links_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "service_type", null: false
    t.string "name", null: false
    t.string "status", null: false
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dokku_id"
    t.index ["org_id"], name: "index_services_on_org_id"
    t.index ["server_id"], name: "index_services_on_server_id"
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
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.text "private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "server_id"], name: "index_ssh_keys_on_id_and_server_id", unique: true
    t.index ["org_id"], name: "index_ssh_keys_on_org_id"
    t.index ["server_id"], name: "index_ssh_keys_on_server_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "apps", "orgs"
  add_foreign_key "apps", "servers"
  add_foreign_key "container_metrics", "containers"
  add_foreign_key "container_metrics", "orgs"
  add_foreign_key "containers", "orgs"
  add_foreign_key "containers", "servers"
  add_foreign_key "environment_configurations", "orgs"
  add_foreign_key "github_access_tokens", "orgs"
  add_foreign_key "github_repos", "apps"
  add_foreign_key "github_repos", "orgs"
  add_foreign_key "memberships", "orgs"
  add_foreign_key "memberships", "users"
  add_foreign_key "server_action_logs", "orgs"
  add_foreign_key "server_action_logs", "server_actions"
  add_foreign_key "server_actions", "memberships"
  add_foreign_key "server_actions", "orgs"
  add_foreign_key "server_actions", "servers"
  add_foreign_key "servers", "orgs"
  add_foreign_key "service_links", "apps"
  add_foreign_key "service_links", "orgs"
  add_foreign_key "service_links", "services"
  add_foreign_key "services", "orgs"
  add_foreign_key "services", "servers"
  add_foreign_key "sessions", "users"
  add_foreign_key "ssh_keys", "orgs"
  add_foreign_key "ssh_keys", "servers"
end
