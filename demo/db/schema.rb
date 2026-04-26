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

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000005) do
  create_table "exchange_trades", force: :cascade do |t|
    t.decimal "bought_atomic", precision: 78, null: false
    t.string "bought_symbol", limit: 10, null: false
    t.string "counterparty", null: false
    t.datetime "created_at", null: false
    t.decimal "settlement_atomic", precision: 78
    t.decimal "sold_atomic", precision: 78, null: false
    t.string "sold_symbol", limit: 10, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "(sold_atomic IS NOT NULL) AND (sold_symbol IS NOT NULL)", name: "exchange_trades_sold_present"
  end

  create_table "treasury_holdings", force: :cascade do |t|
    t.decimal "balance_atomic", precision: 78
    t.string "balance_symbol", limit: 10
    t.datetime "created_at", null: false
    t.decimal "fee_atomic", precision: 78
    t.string "owner", null: false
    t.decimal "reserve_atomic", precision: 40, default: "1250000", null: false
    t.string "reserve_symbol", limit: 10, default: "USDC", null: false
    t.datetime "updated_at", null: false
    t.index ["balance_symbol"], name: "index_treasury_holdings_on_balance_symbol"
    t.index ["owner"], name: "index_treasury_holdings_on_owner"
    t.check_constraint "(balance_atomic IS NULL) = (balance_symbol IS NULL)", name: "treasury_holdings_balance_both_or_neither"
  end

  create_table "treasury_transfers", force: :cascade do |t|
    t.decimal "commission_atomic", precision: 78, default: "100000", null: false
    t.datetime "created_at", null: false
    t.decimal "gross_atomic", precision: 78, null: false
    t.string "gross_symbol", limit: 10, null: false
    t.integer "holding_id", null: false
    t.string "memo"
    t.datetime "updated_at", null: false
    t.index ["holding_id"], name: "index_treasury_transfers_on_holding_id"
  end

  create_table "vault_gold_bars", force: :cascade do |t|
    t.decimal "appraisal_atomic", precision: 78
    t.string "appraisal_symbol", limit: 10
    t.datetime "created_at", null: false
    t.string "serial", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_atomic", precision: 78, null: false
    t.index ["serial"], name: "index_vault_gold_bars_on_serial", unique: true
  end

  create_table "yard_log_shipments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "crew_size", default: 1, null: false
    t.string "origin", null: false
    t.decimal "total_atomic", precision: 78, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "treasury_transfers", "treasury_holdings", column: "holding_id"
end
