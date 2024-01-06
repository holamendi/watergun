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

ActiveRecord::Schema[7.1].define(version: 2024_01_06_162046) do
  create_table "apps", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "name", null: false
    t.string "dokku_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_apps_on_discarded_at"
    t.index ["org_id"], name: "index_apps_on_org_id"
    t.index ["server_id"], name: "index_apps_on_server_id"
  end

  create_table "dokku_users", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.text "ssh_private_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "server_id"], name: "index_dokku_users_on_id_and_server_id", unique: true
    t.index ["org_id"], name: "index_dokku_users_on_org_id"
    t.index ["server_id"], name: "index_dokku_users_on_server_id"
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

  create_table "server_event_logs", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_event_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "server_event_id"], name: "index_server_event_logs_on_id_and_server_event_id", unique: true
    t.index ["org_id"], name: "index_server_event_logs_on_org_id"
    t.index ["server_event_id"], name: "index_server_event_logs_on_server_event_id"
  end

  create_table "server_events", force: :cascade do |t|
    t.integer "org_id", null: false
    t.integer "server_id", null: false
    t.string "eventable_type"
    t.integer "eventable_id"
    t.integer "membership_id"
    t.string "event_type", null: false
    t.string "source", null: false
    t.string "status", null: false
    t.string "job_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "args", default: {}, null: false
    t.datetime "running_at"
    t.json "data", default: {}, null: false
    t.index ["eventable_type", "eventable_id"], name: "index_server_events_on_eventable"
    t.index ["membership_id"], name: "index_server_events_on_membership_id"
    t.index ["org_id"], name: "index_server_events_on_org_id"
    t.index ["server_id"], name: "index_server_events_on_server_id"
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

  add_foreign_key "apps", "orgs"
  add_foreign_key "apps", "servers"
  add_foreign_key "dokku_users", "orgs"
  add_foreign_key "dokku_users", "servers"
  add_foreign_key "git_credentials", "orgs"
  add_foreign_key "memberships", "orgs"
  add_foreign_key "memberships", "users"
  add_foreign_key "server_event_logs", "orgs"
  add_foreign_key "server_event_logs", "server_events"
  add_foreign_key "server_events", "memberships"
  add_foreign_key "server_events", "orgs"
  add_foreign_key "server_events", "servers"
  add_foreign_key "servers", "orgs"
  add_foreign_key "sessions", "users"
end
