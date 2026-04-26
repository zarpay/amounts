require "rails_helper"

# =============================================================================
# Timber Yard — end-to-end cookbook scenario
# =============================================================================
#
# The simplest cookbook. Covers the four canonical split / allocate cases:
#   - 100 logs across a 4-person crew (no remainder)
#   - 10 logs across 3 (the famous "3, 3, 3 with 1 remainder")
#   - allocate by integer weights ([2, 3, 5] proportional shares)
#   - negative totals (corrections, returns) preserving the parts +
#     remainder == original invariant

RSpec.describe "Timber Yard cookbook scenario", :integration, type: :model do
  it "splits 100 logs across a 4-person crew evenly" do
    ship = create(:yard_log_shipment, total: 100, crew_size: 4)
    parts, rem = ship.split_evenly
    expect(parts.map(&:atomic)).to eq([25, 25, 25, 25])
    expect(rem.atomic).to eq(0)
  end

  it "splits 10 logs across 3 unevenly with remainder 1" do
    ship = create(:yard_log_shipment, :uneven)
    parts, rem = ship.split_evenly
    expect(parts.map(&:atomic)).to eq([3, 3, 3])
    expect(rem.atomic).to eq(1)
  end

  it "allocates by crew weights" do
    ship = create(:yard_log_shipment, total: 100, crew_size: 1)
    parts, rem = ship.allocate([2, 3, 5])
    expect(parts.map(&:atomic)).to eq([20, 30, 50])
    expect(rem.atomic).to eq(0)
  end

  it "preserves invariants with negative totals (e.g. corrections)" do
    ship = build(:yard_log_shipment, total: Amount.logs(-7), crew_size: 3)
    parts, rem = ship.split_evenly
    expect(parts.sum(&:atomic) + rem.atomic).to eq(-7)
  end
end
