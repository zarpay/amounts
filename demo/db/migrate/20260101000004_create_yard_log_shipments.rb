# =============================================================================
# yard_log_shipments: minimum-shape `t.amount` for a discrete-quantity type
# =============================================================================
#
# LOGS is registered with decimals: 0, so atomic = UI value exactly. There
# is no fractional log — just a count. The migration is correspondingly
# simple: one fixed-symbol amount and a plain crew_size integer.

class CreateYardLogShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :yard_log_shipments do |t|
      t.string :origin, null: false

      # Fixed-symbol :LOGS amount. Because :LOGS has decimals: 0, this column
      # ends up effectively storing the integer log count, just inside the
      # gem's atomic-storage discipline so split / allocate semantics carry
      # over uniformly with the other domains.
      t.amount :total,
        symbol: :LOGS,
        null:   false

      t.integer :crew_size,
        null:    false,
        default: 1

      t.timestamps
    end
  end
end
