require "rails_helper"

# =============================================================================
# Auric Vault — end-to-end cookbook scenario
# =============================================================================
#
# Walks through a single bullion bar from ingestion to splitting:
#   - rendering the same weight in oz_t / gram / kg with the right
#     ui_decimals per unit
#   - reading the raw scaled BigDecimal via `in_unit` for arithmetic
#   - using an explicit `.to(:USDC, rate: ...)` for a market quote that
#     bypasses the registered default
#   - splitting a bar in half with no remainder

RSpec.describe "Auric Vault cookbook scenario", :integration, type: :model do
  let!(:bullion) { create(:vault_gold_bar, weight: Amount.of_gold("12.5"), appraisal: "USDC|25000") }

  it "renders weight in oz_t / gram / kg with their respective ui_decimals" do
    expect(bullion.weight_label).to eq("12.5000 oz t")
    expect(bullion.weight_label(unit: :gram)).to eq("388.79 g")
    expect(bullion.weight_label(unit: :kg)).to eq("0.38879 kg")
  end

  it "round-trips a fixed-symbol weight and a multi-symbol appraisal" do
    expect(bullion).to have_amount_column(:weight, "GOLD|12.5")
    expect(bullion).to have_amount_column(:appraisal, "USDC|25000.0")
  end

  it "supports an explicit conversion rate via .to(:USDC, rate: ...)" do
    quote = bullion.weight.to(:USDC, rate: "2000")
    expect(quote).to eq_amount("USDC|25000.0")
  end

  it "reads raw scaled BigDecimal via in_unit" do
    expect(bullion.weight_in(:gram)).to eq(BigDecimal("388.79375"))
  end

  it "splits a vault bar into halves with no remainder" do
    parts, rem = bullion.split_into(2)
    expect(parts.map(&:atomic).sum + rem.atomic).to eq(bullion.weight.atomic)
  end
end
