require "rails_helper"

# =============================================================================
# Treasury::WireTransfer spec
# =============================================================================
#
# Covers `has_amount` on a single-table-inheritance subclass:
#
#   - the subclass inherits Transfer's amounts: their introspection, readers,
#     validations (through the gem's validator, which looks definitions up on
#     the record's class) and the RSpec column matcher
#
#   - the subclass's own `wire_fee` reads, validates, and stays off Transfer
#
#   - Rails loads wire transfers as their own class through Transfer

RSpec.describe Treasury::WireTransfer, type: :model do
  let(:holding) { create(:treasury_holding) }
  subject(:wire_transfer) { build(:treasury_wire_transfer, holding: holding) }

  describe "inherited amounts" do
    it "inherits Transfer's amount definitions and adds wire_fee" do
      expect(described_class.amount_attribute_definitions.keys).to eq([:gross, :commission, :wire_fee])
    end

    it "resolves an inherited amount's component columns" do
      expect(described_class.amount_component_columns(:gross)).to eq(["gross_atomic", "gross_symbol"])
    end

    it "reads an inherited amount" do
      expect(wire_transfer.gross).to eq_amount("USDC|50.00")
    end

    it "matches an inherited amount column" do
      expect(create(:treasury_wire_transfer, holding: holding)).to have_amount_column(:gross, "USDC|50.00")
    end

    it "keeps the inherited commission validation" do
      wire_transfer.commission = Amount.of_usdc("-1")
      expect(wire_transfer).not_to be_valid
    end

    it "reports the inherited commission validation" do
      wire_transfer.commission = Amount.of_usdc("-1")
      wire_transfer.valid?
      expect(wire_transfer.errors[:commission].join).to match(/greater than or equal to/)
    end
  end

  describe "wire_fee" do
    it "reads its own fixed-symbol amount" do
      expect(wire_transfer.wire_fee).to eq_amount("USDC|15")
    end

    it "rejects a negative wire fee" do
      wire_transfer.wire_fee = Amount.of_usdc("-1")
      expect(wire_transfer).not_to be_valid
    end

    it "allows no wire fee" do
      wire_transfer.wire_fee = nil
      expect(wire_transfer).to be_valid
    end

    it "is not an amount of Transfer" do
      expect(Treasury::Transfer.amount_attribute_definitions).not_to have_key(:wire_fee)
    end
  end

  describe "single-table inheritance" do
    it "loads through Transfer as a WireTransfer" do
      wire_transfer.save!
      expect(Treasury::Transfer.find(wire_transfer.id)).to be_a(described_class)
    end
  end

  describe "aggregates" do
    before do
      create(:treasury_wire_transfer, holding: holding, commission: 0.10, wire_fee: 15)
      create(:treasury_wire_transfer, holding: holding, commission: 0.20, wire_fee: 20)
      create(:treasury_transfer, holding: holding, commission: 0.40)
    end

    it "totals only wire transfers' commission" do
      expect(described_class.commission_collected).to eq_amount("USDC|0.30")
    end

    it "totals its own wire fee" do
      expect(described_class.sum_amount(:wire_fee)).to eq_amount("USDC|35")
    end

    it "averages its own wire fee, truncated to a whole atomic unit" do
      create(:treasury_wire_transfer, holding: holding, wire_fee: Amount.new(2, :USDC, from: :atomic))
      expect(described_class.average_amount(:wire_fee)).to eq_amount(Amount.new(11_666_667, :USDC, from: :atomic))
    end
  end
end
