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

ActiveRecord::Schema[8.0].define(version: 2025_05_28_093523) do
  create_table "bot_settings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "symbols", default: "[\"AAPL\"]"
    t.string "timeframe", default: "5m"
    t.decimal "profit_percentage", precision: 5, scale: 2, default: "2.0"
    t.decimal "loss_percentage", precision: 5, scale: 2, default: "1.0"
    t.integer "confirmation_bars", default: 3
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bot_settings_on_user_id"
  end

  create_table "bot_states", force: :cascade do |t|
    t.boolean "running", default: false, null: false
    t.datetime "last_run_at"
    t.text "error_message"
    t.string "symbol", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["running"], name: "index_bot_states_on_running"
    t.index ["symbol"], name: "index_bot_states_on_symbol", unique: true
  end

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
    t.string "primary_order_id"
    t.string "take_profit_order_id"
    t.string "stop_loss_order_id"
    t.decimal "fill_qty", precision: 16, scale: 8
    t.decimal "fill_notional", precision: 16, scale: 2
    t.decimal "take_profit", precision: 16, scale: 8
    t.decimal "stop_loss", precision: 16, scale: 8
    t.decimal "current_price", precision: 16, scale: 8
    t.index ["entry_time"], name: "index_positions_on_entry_time"
    t.index ["exit_time"], name: "index_positions_on_exit_time"
    t.index ["primary_order_id"], name: "index_positions_on_primary_order_id"
    t.index ["status"], name: "index_positions_on_status"
    t.index ["stop_loss"], name: "index_positions_on_stop_loss"
    t.index ["symbol"], name: "index_positions_on_symbol"
    t.index ["take_profit"], name: "index_positions_on_take_profit"
    t.index ["user_id"], name: "index_positions_on_user_id"
  end

  create_table "trading_signals", force: :cascade do |t|
    t.string "symbol", limit: 10, null: false
    t.string "signal_type", limit: 20, null: false
    t.decimal "price", precision: 16, scale: 8, null: false
    t.decimal "ema5", precision: 16, scale: 8, null: false
    t.decimal "ema8", precision: 16, scale: 8, null: false
    t.decimal "ema22", precision: 16, scale: 8, null: false
    t.datetime "timestamp", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol", "timestamp"], name: "index_trading_signals_on_symbol_and_timestamp"
    t.index ["timestamp"], name: "index_trading_signals_on_timestamp"
    t.index ["user_id", "symbol", "timestamp"], name: "index_trading_signals_on_user_id_and_symbol_and_timestamp"
    t.index ["user_id"], name: "index_trading_signals_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "bot_settings", "users"
  add_foreign_key "positions", "users"
  add_foreign_key "trading_signals", "users"
end
