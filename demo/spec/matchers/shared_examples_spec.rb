require "rails_helper"

# =============================================================================
# Shared examples in action
# =============================================================================
#
# Demonstrates `it_behaves_like` and `include_examples` against the three
# shared example groups defined in spec/support/shared_examples.rb:
#
#   "a multi-symbol amount column"   round-trip + nil-clear + dirty tracking
#   "a fixed-symbol amount column"   raw numeric input + wrong-symbol reject
#   "a sortable Amount"              Comparable behavior on a symbol
#
# Each shared example takes the attribute name (and a sample value) so it
# can introspect column names via `described_class.amount_atomic_column(...)`
# rather than hardcoding them. This is the same pattern any app extending
# the gem can adopt to keep its own model specs DRY.

RSpec.describe "shared example coverage" do
  describe Treasury::Holding, type: :model do
    subject { build(:treasury_holding) }
    it_behaves_like "a multi-symbol amount column", :balance, sample: "USDC|17.25"
    it_behaves_like "a fixed-symbol amount column", :fee, symbol: :SOL, sample_ui: "0.75"
  end

  describe Vault::GoldBar, type: :model do
    subject { build(:vault_gold_bar) }
    it_behaves_like "a multi-symbol amount column", :appraisal, sample: Amount.usd("1500")
  end

  describe "Comparable on Amount" do
    let(:symbol) { :USDC }
    include_examples "a sortable Amount"
  end
end
