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

ActiveRecord::Schema[8.0].define(version: 2025_05_12_072503) do
  create_table "ema_readings", force: :cascade do |t|
    t.string "symbol", null: false
    t.integer "period", null: false
    t.decimal "value", precision: 16, scale: 8, null: false
    t.datetime "timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol", "period", "timestamp"], name: "index_ema_readings_on_symbol_and_period_and_timestamp"
    t.index ["timestamp"], name: "index_ema_readings_on_timestamp"
  end

  create_table "positions", force: :cascade do |t|
    t.string "symbol", null: false
    t.decimal "amount", precision: 16, scale: 2, null: false
    t.decimal "entry_price", precision: 16, scale: 8, null: false
    t.string "status", default: "open", null: false
    t.decimal "exit_price", precision: 16, scale: 8
    t.string "exit_reason"
    t.datetime "entry_time"
    t.datetime "exit_time"
    t.decimal "profit_loss", precision: 16, scale: 2
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_time"], name: "index_positions_on_entry_time"
    t.index ["exit_time"], name: "index_positions_on_exit_time"
    t.index ["status"], name: "index_positions_on_status"
    t.index ["symbol"], name: "index_positions_on_symbol"
    t.index ["user_id"], name: "index_positions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "positions", "users"
end
