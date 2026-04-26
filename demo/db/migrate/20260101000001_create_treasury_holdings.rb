# =============================================================================
# treasury_holdings: showcase migration for `t.amount`
# =============================================================================
#
# Three different `t.amount` shapes appear here. Together they cover almost
# every option the migration DSL accepts.
#
#   balance   multi-symbol, optional, with a check constraint
#   fee       fixed-symbol :SOL, optional
#   reserve   multi-symbol, narrower precision, default sentinel parsed by
#             the gem, NOT NULL, with a column comment
#
# The generated table looks like:
#
#   balance_atomic   decimal(78, 0)
#   balance_symbol   varchar(10)
#   fee_atomic       decimal(78, 0)
#   reserve_atomic   decimal(40, 0)   default '1250000', NOT NULL
#   reserve_symbol   varchar(10)      default 'USDC',    NOT NULL
#
# Multi-symbol attributes always produce two columns (`*_atomic` and
# `*_symbol`). Fixed-symbol attributes produce just `*_atomic` because the
# symbol is implied by the registry binding. The 78-digit default precision
# is wide enough for 256-bit EVM-scale integers; PostgreSQL is the
# recommended adapter for that range. SQLite stores DECIMAL(78,0) but does
# not round-trip values above 64-bit exactly — the test suite documents that
# limitation explicitly.

class CreateTreasuryHoldings < ActiveRecord::Migration[8.1]
  def change
    create_table :treasury_holdings do |t|
      t.string :owner, null: false

      # Multi-symbol amount. Both columns may be null together; the check
      # constraint below enforces "both or neither" structurally so the
      # database refuses half-set rows even if validations are skipped.
      t.amount :balance,
        null:    true,
        comment: "any registered symbol"

      # Fixed-symbol amount. The `symbol:` option binds the column to :SOL
      # at the migration level. The gem then omits the `*_symbol` column
      # since the symbol is already known.
      t.amount :fee,
        symbol:  :SOL,
        null:    true,
        comment: "fixed-symbol fee column"

      # The `default:` sentinel is parsed by the gem at migration time:
      # "USDC|1.25" splits into atomic default "1250000" and symbol default
      # "USDC". The narrower precision: 40 is a deliberate contrast with
      # the default 78 — useful when storage size matters and the values
      # never exceed 128-bit-ish range.
      t.amount :reserve,
        precision: 40,
        default:   "USDC|1.25",
        null:      false,
        comment:   "default sentinel parsed by the gem"

      t.timestamps
    end

    # The "both atomic and symbol or neither" rule is also enforced by the
    # has_amount validator at the model layer, but a database constraint
    # protects against half-state rows inserted bypassing AR (raw SQL,
    # bulk loads, future migrations).
    add_check_constraint :treasury_holdings,
      "(balance_atomic IS NULL) = (balance_symbol IS NULL)",
      name: "treasury_holdings_balance_both_or_neither"

    # Indexing the symbol column accelerates `where balance_symbol = 'USDC'`
    # queries, which is the underlying SQL for the gem's `balance_in(:USDC)`
    # scope and for `group(:balance_symbol).sum(:balance_atomic)` reports.
    add_index :treasury_holdings, :balance_symbol
    add_index :treasury_holdings, :owner
  end
end
