# =============================================================================
# treasury_transfers: child of treasury_holdings
# =============================================================================
#
# Demonstrates two concepts not covered by treasury_holdings:
#
#   - `t.references` alongside `t.amount` (the gem and Rails compose
#     normally — there is nothing special about combining them)
#   - a fixed-symbol amount with a numeric `default:` parsed via the
#     compact-string format ("USDC|0.10" -> atomic 100000)

class CreateTreasuryTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :treasury_transfers do |t|
      t.references :holding,
        null:        false,
        foreign_key: { to_table: :treasury_holdings }

      # Multi-symbol gross amount: a transfer can be denominated in any
      # currency the treasury holds.
      t.amount :gross, null: false

      # Fixed-symbol commission. The default sentinel "USDC|0.10" is parsed
      # at migration time — atomic default becomes 100000 (six decimals).
      t.amount :commission,
        symbol:  :USDC,
        null:    false,
        default: "USDC|0.10"

      t.string :memo

      t.timestamps
    end
  end
end
