require "rails_helper"

# =============================================================================
# Gem-provided RSpec matchers — every form, every input shape
# =============================================================================
#
# The matchers ship in two namespaces:
#
#   Amount::RSpec::Matchers              core, in `amount/rspec`
#   Amount::ActiveRecord::RSpec::Matchers AR-specific, in `amount/active_record/rspec`
#
# Both are loaded by rails_helper and the names are mixed into RSpec's
# global matcher registry, so specs use the bare names.
#
# Matchers covered:
#
#   eq_amount                  exact equality, multiple input forms
#   be_amount_of               symbol identity
#   be_zero/positive/negative  sign predicates
#   be_approximately_amount    within: tolerance, multiple input shapes
#
#   have_amount_column         (AR) reader + atomic + symbol all match
#   match_amounts              (AR) group(...).sum(...) round-trip
#
# `define_negated_matcher` is also demonstrated to show how to compose
# new matchers on top of the gem's. Useful if you want a domain matcher
# like `not_be_amount_of(:USDC)` that reads more naturally than `not_to`.

RSpec::Matchers.define_negated_matcher :not_be_amount_of, :be_amount_of

RSpec.describe "amount/rspec matchers", :aggregate_failures do
  describe "eq_amount" do
    it "accepts a compact-string expectation" do
      expect(Amount.usdc("1.50")).to eq_amount("USDC|1.5")
    end

    it "accepts (:SYMBOL, value) expectation" do
      expect(Amount.usdc("1.50")).to eq_amount(:USDC, "1.5")
    end

    it "accepts another Amount as expectation" do
      expect(Amount.usdc("1.50")).to eq_amount(Amount.usdc("1.5"))
    end

    it "accepts a hash payload (Amount.load form)" do
      expect(Amount.usdc("1.50")).to eq_amount(v: 1, atomic: "1500000", symbol: "USDC")
    end

    it "fails on different symbol" do
      expect(Amount.usdc("1")).not_to eq_amount("SOL|1")
    end
  end

  describe "be_amount_of" do
    it "matches the symbol" do
      expect(Amount.sol("1.5")).to be_amount_of(:SOL)
    end

    it "composes with define_negated_matcher" do
      expect(Amount.usdc("1")).to not_be_amount_of(:SOL)
    end
  end

  describe "predicate matchers" do
    specify { expect(Amount.usdc(0, from: :atomic)).to be_zero_amount }
    specify { expect(Amount.usdc("1")).to be_positive_amount }
    specify { expect(Amount.usdc("-1")).to be_negative_amount }
  end

  describe "be_approximately_amount" do
    it "passes within the tolerance window" do
      expect(Amount.usdc("1.51")).to be_approximately_amount(:USDC, "1.50", within: "0.05")
    end

    it "fails outside the window", aggregate_failures: false do
      expect {
        expect(Amount.usdc("2.00")).to be_approximately_amount(:USDC, "1.50", within: "0.05")
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "accepts an Amount as expected and within" do
      expected = Amount.usdc("1.50")
      delta = Amount.usdc("0.10")
      expect(Amount.usdc("1.55")).to be_approximately_amount(expected, within: delta)
    end
  end

  describe "have_amount_column (AR matcher)" do
    let(:holding) { create(:treasury_holding, balance: "USDC|10.50", fee: Amount.sol("0.5")) }

    it "matches a multi-symbol amount column" do
      expect(holding).to have_amount_column(:balance, "USDC|10.5")
    end

    it "matches a fixed-symbol amount column" do
      expect(holding).to have_amount_column(:fee, Amount.sol("0.5"))
    end
  end

  describe "match_amounts (AR aggregation matcher)" do
    before do
      create(:treasury_holding, balance: "USDC|10")
      create(:treasury_holding, balance: "USDC|1.50")
      create(:treasury_holding, :sol_balance)
    end

    it "matches grouped sums of atomic columns by symbol" do
      sums = Treasury::Holding.group(:balance_symbol).sum(:balance_atomic)
      expect(sums).to match_amounts(USDC: "11.50", SOL: "12.5")
    end
  end
end
