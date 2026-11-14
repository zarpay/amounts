# =============================================================================
# treasury_transfers: single-table inheritance for Treasury::WireTransfer
# =============================================================================
#
# Demonstrates `has_amount` on an STI subclass:
#
#   - a `type` column, so Rails loads each row as its own class
#   - a fixed-symbol amount only the subclass declares. Plain transfers
#     leave it NULL, so the column allows nulls.

class AddWireTransfers < ActiveRecord::Migration[8.1]
  def change
    change_table :treasury_transfers do |t|
      t.string :type

      t.amount :wire_fee, symbol: :USDC, null: true
    end
  end
end
