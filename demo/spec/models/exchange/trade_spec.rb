require "rails_helper"

# =============================================================================
# Exchange::Trade spec — directional rates and cross-type arithmetic
# =============================================================================
#
# The Ember cookbook is the home for cross-type behavior. Tests cover:
#
#   - conditional validations that fire only for a specific symbol
#     (the EMBER-only thresholds)
#
#   - implied-rate computation that returns nil rather than raising when
#     no rate path can bridge the two sides (e.g. EMBER vs SILVER, where
#     neither directional rate is registered)
#
#   - `settle!` using the registered USD rate, plus the explicit-rate
#     override for negotiated trades
#
#   - factory traits like `:settled` exercise the `after(:create)` hook
#     pattern so persistence-then-side-effect chains can be tested in
#     one line

RSpec.describe Exchange::Trade, type: :model do
  describe "validations" do
    it "rejects EMBER sold = 0 (greater_than threshold)" do
      trade = build(:exchange_trade, sold: Amount.of_ember("0"), bought: Amount.of_usd("0.01"))
      expect(trade).not_to be_valid
      expect(trade.errors[:sold].join).to match(/greater than/)
    end

    it "is_valid when sold is non-EMBER (conditional skip)" do
      trade = build(:exchange_trade, :silver_for_usd)
      expect(trade).to be_valid
    end
  end

  describe "cross-type arithmetic via implied_rate" do
    it "computes a rate when EMBER->USD path exists" do
      trade = build(:exchange_trade, sold: Amount.of_ember("100"), bought: Amount.of_usd("25"))
      # Both bought and sold need to be in the same symbol; bought.to(:EMBER)
      # requires a USD->EMBER rate which is registered.
      expect(trade.implied_rate).to eq(BigDecimal("1"))
    end

    it "returns nil when no rate path exists" do
      trade = build(:exchange_trade, sold: Amount.of_ember("100"), bought: Amount.of_silver("1"))
      expect(trade.implied_rate).to be_nil
    end
  end

  describe "#settle!" do
    it "uses the registered default rate when no explicit rate is provided" do
      trade = create(:exchange_trade, sold: Amount.of_ember("100"), bought: Amount.of_usd("25"))
      result = trade.settle!
      expect(result).to be_amount_of(:USD)
      expect(result.decimal).to eq(BigDecimal("25"))
    end

    it "accepts an explicit rate that overrides the default" do
      trade = create(:exchange_trade, sold: Amount.of_ember("100"), bought: Amount.of_usd("25"))
      result = trade.settle!(rate: "0.5")
      expect(result.decimal).to eq(BigDecimal("50"))
    end
  end

  describe "settled trait fully exercises the .create -> after(:create) -> settle! chain" do
    let(:trade) { create(:exchange_trade, :settled) }

    it "persists settlement after create" do
      expect(trade.settlement).to be_amount_of(:USD)
    end
  end
end
