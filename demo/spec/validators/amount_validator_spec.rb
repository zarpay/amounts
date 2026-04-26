require "rails_helper"

# =============================================================================
# AmountValidator spec — every option of `validates :x, amount: { ... }`
# =============================================================================
#
# The gem ships an `EachValidator` registered as `:amount` (via the
# top-level `AmountValidator` alias) that supports:
#
#   symbol:                    require a specific symbol identity
#   greater_than:              strict lower bound
#   greater_than_or_equal_to:  inclusive lower bound
#   less_than:                 strict upper bound
#   less_than_or_equal_to:     inclusive upper bound
#   allow_nil:                 standard Rails option
#
# Thresholds may be:
#   - Amount instances (symmetric across attribute types)
#   - compact strings ("USDC|0")
#   - raw numerics (interpreted as UI values; for multi-symbol attributes
#     since 0.0.2 they assume the value's symbol at validation time)
#
# Cross-type comparison goes through `<=>` and uses the registered
# directional rate when one exists. Without a rate the validator surfaces
# a "cannot compare X to Y for op" error rather than crashing.
#
# Each describe block here defines a fresh ad-hoc model class via a
# helper so the validator under test is the only one running. The classes
# get named via `stub_const` because anonymous AR subclasses don't play
# well with introspection helpers like `amount_attribute_definitions`.
RSpec.describe Amount::ActiveRecord::AmountValidator, type: :model do
  def define_holding_with(validation:, name: "ValidatedHolding")
    klass = Class.new(ApplicationRecord) do
      self.table_name = "treasury_holdings"
      has_amount :balance
      has_amount :fee, symbol: :SOL
      has_amount :reserve
      validates :owner, presence: true
      validates :balance, amount: validation
    end
    stub_const(name, klass)
    klass
  end

  describe "symbol: option" do
    let(:klass) { define_holding_with(validation: { symbol: :USDC }) }

    it "accepts a value with the matching symbol" do
      expect(klass.new(owner: "x", balance: Amount.usdc("1"))).to be_valid
    end

    it "rejects a value with a different symbol" do
      record = klass.new(owner: "x", balance: Amount.sol("1"))
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/must have symbol USDC/)
    end
  end

  describe "every comparator with Amount-typed thresholds" do
    let(:klass) do
      define_holding_with(validation: {
        greater_than: "USDC|0",
        greater_than_or_equal_to: "USDC|1",
        less_than: "USDC|100",
        less_than_or_equal_to: "USDC|99"
      })
    end

    it "passes a value satisfying every comparator" do
      expect(klass.new(owner: "x", balance: Amount.usdc("50"))).to be_valid
    end

    it "fails a value below greater_than_or_equal_to" do
      record = klass.new(owner: "x", balance: Amount.usdc("0.5"))
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/greater than or equal to/)
    end

    it "fails a value at less_than (boundary, exclusive)" do
      record = klass.new(owner: "x", balance: Amount.usdc("100"))
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/less than/)
    end

    it "fails a value above less_than_or_equal_to" do
      expect(klass.new(owner: "x", balance: Amount.usdc("99.01"))).not_to be_valid
    end

    it "passes the upper boundary of less_than_or_equal_to" do
      expect(klass.new(owner: "x", balance: Amount.usdc("99"))).to be_valid
    end
  end

  describe "numeric thresholds on multi-symbol attributes (fixed in 0.0.2)" do
    let(:klass) { define_holding_with(validation: { greater_than: 1 }) }

    it "treats `greater_than: 1` as 1 USDC against a USDC value" do
      expect(klass.new(owner: "x", balance: Amount.usdc("0.5"))).not_to be_valid
      expect(klass.new(owner: "x", balance: Amount.usdc("2"))).to be_valid
    end

    it "treats the SAME `greater_than: 1` as 1 SOL against a SOL value" do
      expect(klass.new(owner: "x", balance: Amount.sol("0.5"))).not_to be_valid
      expect(klass.new(owner: "x", balance: Amount.sol("2"))).to be_valid
    end
  end

  describe "cross-type threshold without a registered rate" do
    let(:klass) { define_holding_with(validation: { greater_than: "EMBER|1" }) }

    it "surfaces 'cannot compare X to Y for op' instead of crashing" do
      record = klass.new(owner: "x", balance: Amount.usdc("100"))
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/cannot compare USDC to EMBER for greater_than/)
    end
  end

  describe "cross-type threshold WITH a registered rate (USDC↔USD)" do
    let(:klass) { define_holding_with(validation: { greater_than: "USD|1.00" }) }

    it "compares via the directional rate (USDC value satisfies USD threshold)" do
      expect(klass.new(owner: "x", balance: Amount.usdc("2.00"))).to be_valid
      expect(klass.new(owner: "x", balance: Amount.usdc("0.50"))).not_to be_valid
    end
  end

  describe "allow_nil:" do
    let(:klass) { define_holding_with(validation: { greater_than: "USDC|0", allow_nil: true }) }

    it "skips the comparator when the attribute is nil" do
      expect(klass.new(owner: "x", balance: nil)).to be_valid
    end

    it "still fires when the attribute is present" do
      expect(klass.new(owner: "x", balance: Amount.usdc("0"))).not_to be_valid
    end
  end

  describe "fixed-symbol attribute with numeric thresholds" do
    let(:klass) do
      Class.new(ApplicationRecord) do
        self.table_name = "treasury_holdings"
        has_amount :balance
        has_amount :fee, symbol: :SOL
        has_amount :reserve
        validates :owner, presence: true
        validates :fee, amount: { greater_than: 0, less_than: 5, allow_nil: true }
      end.tap { |k| stub_const("FixedFeeHolding", k) }
    end

    it "compares numeric thresholds in UI units against the value" do
      expect(klass.new(owner: "x", fee: Amount.sol("3"))).to be_valid
      expect(klass.new(owner: "x", fee: Amount.sol("0"))).not_to be_valid
      expect(klass.new(owner: "x", fee: Amount.sol("5.5"))).not_to be_valid
    end

    it "skips when fee is nil thanks to allow_nil" do
      expect(klass.new(owner: "x", fee: nil)).to be_valid
    end
  end

  describe "validator error path: pending assignment errors take precedence" do
    let(:klass) { define_holding_with(validation: { greater_than: "USDC|0" }) }

    it "surfaces a writer cast error before invoking the comparator" do
      record = klass.new(owner: "x")
      record.balance = "not a parseable amount"
      expect(record).not_to be_valid
      # The structural validator surfaces the cast error directly, the
      # AmountValidator short-circuits via pending_assignment_error?.
      expect(record.errors[:balance]).not_to be_empty
    end
  end
end
