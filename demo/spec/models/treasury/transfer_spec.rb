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
#
#   - SQL aggregates returning Amounts: a fixed-symbol total that is zero
#     over no rows, totals scoped through an association, a truncated
#     average, and multi-symbol totals grouped by symbol (ungrouped, they
#     raise across currencies)

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
      transfer.commission = Amount.of_usdc("-1")
      expect(transfer).not_to be_valid
      expect(transfer.errors[:commission].join).to match(/greater than or equal to/)
    end

    it "skips greater_than check when gross symbol is not USDC (conditional)" do
      transfer.gross = Amount.of_sol("0")
      expect(transfer).to be_valid
    end

    it "fires greater_than when gross symbol is USDC" do
      transfer.gross = Amount.of_usdc("0")
      expect(transfer).not_to be_valid
    end
  end

  describe "#net" do
    it "computes gross - commission for same-type" do
      transfer.gross = Amount.of_usdc("100")
      transfer.commission = Amount.of_usdc("0.5")
      expect(transfer.net).to eq_amount("USDC|99.5")
    end

    it "returns nil when types differ and there is no rate" do
      transfer.gross = Amount.of_ember("100")
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

  describe "aggregates" do
    let(:other_holding) { create(:treasury_holding) }

    before do
      create(:treasury_transfer, holding: holding, gross: "USDC|50", commission: 0.10)
      create(:treasury_transfer, holding: holding, gross: "USDC|200", commission: 0.25)
      create(:treasury_transfer, :sol, holding: other_holding, commission: 0.40)
    end

    it "totals commission as a USDC amount" do
      expect(described_class.commission_collected).to eq_amount("USDC|0.75")
    end

    it "totals commission over no transfers as zero" do
      expect(described_class.none.commission_collected).to eq_amount("USDC|0")
    end

    it "totals one holding's commission through the association" do
      expect(holding.transfers.commission_collected).to eq_amount("USDC|0.35")
    end

    it "averages commission as a USDC amount" do
      expect(described_class.average_commission).to eq_amount("USDC|0.25")
    end

    it "totals gross per currency" do
      expect(described_class.gross_by_symbol).to eq("USDC" => Amount.of_usdc("250"), "SOL" => Amount.of_sol("1"))
    end

    it "finds the largest gross per currency" do
      expect(described_class.largest_gross_by_symbol).to eq("USDC" => Amount.of_usdc("200"), "SOL" => Amount.of_sol("1"))
    end

    it "refuses to total gross across currencies" do
      expect { described_class.sum_amount(:gross) }.to raise_error(Amount::TypeMismatch)
    end

    it "totals gross in one currency" do
      expect(described_class.where(gross_symbol: "USDC").sum_amount(:gross)).to eq_amount("USDC|250")
    end
  end
end
