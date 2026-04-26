require "rails_helper"

# =============================================================================
# Treasury::Transfer spec
# =============================================================================
#
# Covers the secondary treasury model. Distinct lessons vs. Holding:
#
#   - fixed-symbol :USDC commission with a migration default of "USDC|0.10"
#     — exercised directly to prove the gem parses default sentinels at
#     migration time (atomic 100_000)
#
#   - conditional validations driven by an Amount predicate (`if:` block
#     that reads `gross&.symbol`) — proves the gem's validator composes
#     with Rails' standard conditionals
#
#   - same-type subtraction (`net`) that returns nil rather than raising
#     when symbols don't match — useful pattern for UI affordances
#
#   - between-style scope (`within_range`) layered on the generated
#     `where_gross_between(low, high)`

RSpec.describe Treasury::Transfer, type: :model do
  let(:holding) { create(:treasury_holding) }
  subject(:transfer) { build(:treasury_transfer, holding: holding) }

  describe "schema" do
    it "exposes commission as a fixed-symbol USDC attribute" do
      expect(described_class.amount_component_columns(:commission)).to eq(["commission_atomic"])
      expect(described_class.amount_attribute_definitions[:commission].symbol).to eq(:USDC)
    end

    it "applies the migration default for commission" do
      record = described_class.new(holding: holding, gross: "USDC|10")
      expect(record.commission).to eq_amount("USDC|0.10")
    end
  end

  describe "validations" do
    it "rejects negative commission" do
      transfer.commission = Amount.usdc("-1")
      expect(transfer).not_to be_valid
      expect(transfer.errors[:commission].join).to match(/greater than or equal to/)
    end

    it "skips greater_than check when gross symbol is not USDC (conditional)" do
      transfer.gross = Amount.sol("0")
      expect(transfer).to be_valid
    end

    it "fires greater_than when gross symbol is USDC" do
      transfer.gross = Amount.usdc("0")
      expect(transfer).not_to be_valid
    end
  end

  describe "#net" do
    it "computes gross - commission for same-type" do
      transfer.gross = Amount.usdc("100")
      transfer.commission = Amount.usdc("0.5")
      expect(transfer.net).to eq_amount("USDC|99.5")
    end

    it "returns nil when types differ and there is no rate" do
      transfer.gross = Amount.ember("100")
      expect(transfer.net).to be_nil
    end
  end

  describe "scopes" do
    it "exposes .large via where_gross_gt" do
      large_one = create(:treasury_transfer, holding: holding, gross: "USDC|500")
      _small = create(:treasury_transfer, holding: holding, gross: "USDC|10")
      expect(described_class.large).to include(large_one)
    end

    it "supports between via custom scope" do
      mid = create(:treasury_transfer, holding: holding, gross: "USDC|50")
      _high = create(:treasury_transfer, holding: holding, gross: "USDC|500")
      _low = create(:treasury_transfer, holding: holding, gross: "USDC|5")
      expect(described_class.within_range("USDC|10", "USDC|100")).to contain_exactly(mid)
    end
  end
end
