require "rails_helper"

# =============================================================================
# Yard::LogShipment spec — split / allocate semantics on a decimals: 0 type
# =============================================================================
#
# The Timber cookbook strips away every concern except integer-style
# amounts and exact division. Three lessons:
#
#   1. With decimals: 0, atomic value equals UI value. Integer input "is"
#      the count — no precision conversion to think about.
#
#   2. `split(n)` returns `[parts, remainder]`. The harness's central
#      invariant: parts.sum + remainder == original, every time, including
#      negative totals.
#
#   3. `allocate(weights)` distributes proportionally, so [1, 1, 2] gives
#      the third party twice as much as the others. Same invariant applies.
#
# The fixed-symbol scope `where_total_gt(50)` accepts a raw numeric directly
# because the symbol is implied by the registry binding.

RSpec.describe Yard::LogShipment, type: :model do
  subject(:shipment) { build(:yard_log_shipment) }

  describe "schema" do
    it "stores total as a fixed-symbol LOGS attribute" do
      expect(described_class.amount_component_columns(:total)).to eq(["total_atomic"])
    end
  end

  describe "decimals: 0 means atomic == ui" do
    it "treats Integer input as the literal log count" do
      shipment.total = 7
      expect(shipment.total.atomic).to eq(7)
      expect(shipment.total.decimal).to eq(BigDecimal("7"))
    end
  end

  describe "split_evenly" do
    it "splits 100 logs across 4 crew (no remainder)" do
      parts, rem = shipment.split_evenly
      expect(parts.map(&:atomic)).to eq([25, 25, 25, 25])
      expect(rem.atomic).to eq(0)
    end

    it "preserves the invariant for uneven splits" do
      uneven = build(:yard_log_shipment, :uneven)
      parts, rem = uneven.split_evenly
      expect(parts.map(&:atomic).sum + rem.atomic).to eq(uneven.total.atomic)
    end
  end

  describe "allocate" do
    it "allocates by integer weights" do
      shipment.total = 10
      parts, rem = shipment.allocate([1, 1, 2])
      expect(parts.map(&:atomic)).to eq([2, 2, 5])
      expect(rem.atomic).to eq(1)
    end
  end

  describe "scopes" do
    it ".heavy filters via where_total_gt with raw numeric" do
      heavy = create(:yard_log_shipment, total: 200)
      _light = create(:yard_log_shipment, total: 10)
      expect(described_class.heavy).to include(heavy)
    end
  end
end
