# =============================================================================
# exchange_trades: every column is an Amount of some kind
# =============================================================================
#
# A trade has three amount fields:
#
#   sold        what was given up   (multi-symbol, required)
#   bought      what was received   (multi-symbol, required)
#   settlement  USD-equivalent      (fixed-symbol :USD, optional)
#
# The check constraint below enforces sold's both-or-neither pattern at the
# database layer. We don't need it for `bought` because both columns are
# already NOT NULL (Rails won't insert with one missing).

class CreateExchangeTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_trades do |t|
      t.string :counterparty, null: false

      t.amount :sold,   null: false
      t.amount :bought, null: false

      # Fixed-symbol settlement column — populated lazily after a price
      # quote, so it's nullable.
      t.amount :settlement,
        symbol: :USD,
        null:   true

      t.timestamps
    end

    # `sold` is multi-symbol AND NOT NULL, so this constraint is really
    # a belt-and-braces check that someone didn't update_column past the
    # validations. It still teaches the pattern.
    add_check_constraint :exchange_trades,
      "(sold_atomic IS NOT NULL) AND (sold_symbol IS NOT NULL)",
      name: "exchange_trades_sold_present"
  end
end
