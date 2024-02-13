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

ActiveRecord::Schema[7.1].define(version: 2024_02_13_185357) do
  create_table "action_logs", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "action_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "ssh_commands", default: [], null: false
    t.index ["action_id"], name: "index_action_logs_on_action_id"
    t.index ["id", "action_id"], name: "index_action_logs_on_id_and_action_id", unique: true
    t.index ["org_id"], name: "index_action_logs_on_org_id"
  end

  create_table "actions", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "actionable_type"
    t.integer "actionable_id"
    t.integer "membership_id"
    t.string "action_type", null: false
    t.string "source", null: false
    t.string "status", null: false
    t.string "job_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "args", default: {}, null: false
    t.datetime "running_at"
    t.json "data", default: {}, null: false
    t.json "payload", default: {}, null: false
    t.index ["actionable_type", "actionable_id"], name: "index_server_events_on_actionable"
    t.index ["membership_id"], name: "index_actions_on_membership_id"
    t.index ["org_id"], name: "index_actions_on_org_id"
    t.index ["server_id"], name: "index_actions_on_server_id"
  end

  create_table "app_sources", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "app_id", null: false
    t.string "type", null: false
    t.json "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_app_sources_on_app_id"
    t.index ["org_id"], name: "index_app_sources_on_org_id"
  end

  create_table "apps", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "name", null: false
    t.string "dokku_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.string "status"
    t.index ["discarded_at"], name: "index_apps_on_discarded_at"
    t.index ["org_id"], name: "index_apps_on_org_id"
    t.index ["server_id"], name: "index_apps_on_server_id"
    t.index ["status"], name: "index_apps_on_status"
  end

  create_table "git_credentials", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "provider", null: false
    t.string "description"
    t.string "personal_access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_git_credentials_on_org_id"
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

  create_table "server_identities", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.text "ssh_private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "server_id"], name: "index_server_identities_on_id_and_server_id", unique: true
    t.index ["org_id"], name: "index_server_identities_on_org_id"
    t.index ["server_id"], name: "index_server_identities_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "provider", null: false
    t.string "name", null: false
    t.string "dokku_token", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}
    t.integer "org_id", null: false
    t.index ["dokku_token"], name: "index_servers_on_dokku_token", unique: true
    t.index ["org_id"], name: "index_servers_on_org_id"
  end

  create_table "service_links", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "service_id", null: false
    t.integer "app_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_service_links_on_app_id"
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

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "action_logs", "actions"
  add_foreign_key "action_logs", "orgs"
  add_foreign_key "actions", "memberships"
  add_foreign_key "actions", "orgs"
  add_foreign_key "actions", "servers"
  add_foreign_key "app_sources", "apps"
  add_foreign_key "app_sources", "orgs"
  add_foreign_key "apps", "orgs"
  add_foreign_key "apps", "servers"
  add_foreign_key "git_credentials", "orgs"
  add_foreign_key "memberships", "orgs"
  add_foreign_key "memberships", "users"
  add_foreign_key "server_identities", "orgs"
  add_foreign_key "server_identities", "servers"
  add_foreign_key "servers", "orgs"
  add_foreign_key "service_links", "apps"
  add_foreign_key "service_links", "orgs"
  add_foreign_key "service_links", "services"
  add_foreign_key "services", "orgs"
  add_foreign_key "services", "servers"
  add_foreign_key "sessions", "users"
end
