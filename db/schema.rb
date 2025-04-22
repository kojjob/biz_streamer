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

ActiveRecord::Schema[8.0].define(version: 2025_04_22_103450) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "username"
    t.string "display_name"
    t.text "bio"
    t.string "profile_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "headline", limit: 100
    t.date "birth_date"
    t.string "gender"
    t.string "preferred_language", default: "en"
    t.jsonb "social_links", default: {}
    t.string "contact_email"
    t.string "public_phone"
    t.text "expertise", default: [], array: true
    t.jsonb "education", default: []
    t.jsonb "work_experience", default: []
    t.jsonb "certifications", default: []
    t.integer "streams_count", default: 0
    t.integer "total_sales_count", default: 0
    t.decimal "total_commission_earned", precision: 12, scale: 2, default: "0.0"
    t.boolean "is_recommended", default: false
    t.integer "trust_score", default: 0
    t.string "ambassador_level", default: "bronze"
    t.jsonb "badges", default: {}
    t.jsonb "privacy_settings", default: {"show_email" => false, "show_phone" => false, "show_location" => true, "show_birth_date" => false, "show_sales_metrics" => true}
    t.jsonb "notification_preferences", default: {"push_messages" => true, "email_marketing" => true, "push_stream_start" => true, "email_order_updates" => true, "email_stream_notifications" => true}
    t.string "theme_preference", default: "light"
    t.string "accent_color"
    t.jsonb "layout_preferences", default: {}
    t.jsonb "availability_hours", default: {}
    t.boolean "open_for_collaboration", default: true
    t.decimal "min_collaboration_budget", precision: 10, scale: 2
    t.jsonb "content_interests", default: []
    t.jsonb "shopping_preferences", default: {}
    t.index ["ambassador_level"], name: "index_profiles_on_ambassador_level"
    t.index ["content_interests"], name: "index_profiles_on_content_interests", using: :gin
    t.index ["expertise"], name: "index_profiles_on_expertise", using: :gin
    t.index ["is_recommended"], name: "index_profiles_on_is_recommended"
    t.index ["privacy_settings"], name: "index_profiles_on_privacy_settings", using: :gin
    t.index ["social_links"], name: "index_profiles_on_social_links", using: :gin
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "stripe_customer_id"
    t.string "stripe_connect_account_id"
    t.integer "role", default: 0, null: false
    t.boolean "is_verified", default: false
    t.datetime "last_activity_at"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["stripe_connect_account_id"], name: "index_users_on_stripe_connect_account_id"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "profiles", "users"
end
