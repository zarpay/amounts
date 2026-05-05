require "rails_helper"

# =============================================================================
# Ember Exchange — end-to-end cookbook scenario
# =============================================================================
#
# Cross-type arithmetic and asymmetric directional rates in action:
#   - EMBER<->USD trades (both directions registered)
#   - SILVER->USD trades (only the one direction registered; the reverse
#     raises NoDefaultRate)
#   - implicit cross-type addition (USDC + USD via the registered rate)
#   - chained .to() conversions (SOL -> USDC -> USD)

RSpec.describe "Ember Exchange cookbook scenario", :integration, type: :model do
  it "trades EMBER for USD using directional default rates" do
    trade = create(:exchange_trade, sold: Amount.of_ember("100"), bought: Amount.of_usd("25"))
    settled = trade.settle!
    expect(settled).to eq_amount("USD|25.0")
  end

  it "trades SILVER for USD using only the SILVER->USD direction" do
    trade = create(:exchange_trade, :silver_for_usd)
    expect(Amount.registry.default_rate(:SILVER, :USD)).to eq(BigDecimal("30"))
    settled = trade.settle!
    expect(settled).to eq_amount("USD|30.0")
  end

  it "raises NoDefaultRate when only the reverse direction is registered" do
    trade = build(:exchange_trade, sold: Amount.of_silver("1"))
    # USD->SILVER is NOT registered; an explicit conversion fails.
    expect { Amount.of_usd("1").to(:SILVER) }.to raise_error(Amount::Registry::NoDefaultRate)
  end

  it "supports cross-type addition through registered rates (USDC + USD)" do
    sum = Amount.of_usdc("1") + Amount.of_usd("2")
    expect(sum).to be_amount_of(:USDC)
    expect(sum.decimal).to eq(BigDecimal("3"))
  end

  it "supports chained .to() conversions: SOL -> USDC -> USD" do
    one_sol = Amount.of_sol("1")
    in_usdc = one_sol.to(:USDC)
    in_usd  = in_usdc.to(:USD)
    expect(in_usd).to be_amount_of(:USD)
    expect(in_usd.decimal).to eq(BigDecimal("150"))
  end
end
