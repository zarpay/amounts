# =============================================================================
# vault_gold_bars: GOLD as a fixed-symbol attribute, plus a multi-symbol
# appraisal column
# =============================================================================
#
# `weight` is fixed to :GOLD, so the appraisal price is the only attribute
# that varies by currency. This is the natural shape for a vault — bullion
# is always weighed in GOLD, but its market value is whatever the appraiser
# quotes (USD, USDC, etc).

class CreateVaultGoldBars < ActiveRecord::Migration[8.1]
  def change
    create_table :vault_gold_bars do |t|
      t.string :serial,
        null:  false,
        index: { unique: true }

      # Fixed-symbol :GOLD column. Storage is decimal(78, 0) at 8 decimals,
      # so one troy ounce is stored as 100_000_000 atomic units.
      t.amount :weight,
        symbol: :GOLD,
        null:   false

      # Multi-symbol appraisal — an optional valuation in any registered
      # currency. Nullable because not every bar has been appraised yet.
      t.amount :appraisal,
        null:    true,
        comment: "any currency the appraiser quotes"

      t.timestamps
    end
  end
end
