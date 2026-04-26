require "rails_helper"

# =============================================================================
# Treasury::Holding spec — the harness's flagship model spec
# =============================================================================
#
# This file is the most thorough demonstration of `has_amount` usage in
# context. The describe blocks track the model's surface area:
#
#   schema and macro wiring        introspection helpers exposed on the
#                                  class (amount_attribute_definitions,
#                                  amount_component_columns, etc.)
#
#   the writer accepts every       Amount, compact string, {atomic:,symbol:}
#   documented input form          hash, {value:,symbol:} hash, raw numeric
#                                  (fixed-symbol only), nil
#
#   structural validations         "must set both atomic and symbol or
#   from has_amount                neither" + cross-symbol writer rejection
#
#   Type#cast input edge cases     hash missing keys, unsupported class,
#   (surfaced via writer)          empty string
#
#   AmountValidator                each comparator option exercised on
#   (validates :x, amount: { … })  a different attribute
#
#   dirty tracking helpers         _changed?, _was, _change, saved_*
#
#   scopes provided by has_amount  where_*, between, in
#
#   user scopes layered on the     custom .rich, .with_balance_in
#   generated ones
#
#   match_amounts aggregation      group(:balance_symbol).sum(:balance_atomic)
#   matcher                        round-trip
#
#   associations                   shoulda has_many :transfers
#
#   #total_in cross-type           model-level cross-currency conversion
#   aggregation                    using `.to(:SYMBOL)`

RSpec.describe Treasury::Holding, type: :model do
  subject(:holding) { build(:treasury_holding) }

  describe "schema and macro wiring" do
    it "exposes amount attribute definitions" do
      expect(described_class.amount_attribute_definitions.keys).to eq([:balance, :fee, :reserve])
    end

    it "knows the multi-symbol component columns" do
      expect(described_class.amount_component_columns(:balance)).to eq(["balance_atomic", "balance_symbol"])
      expect(described_class.amount_atomic_column(:balance)).to eq("balance_atomic")
      expect(described_class.amount_symbol_column(:balance)).to eq("balance_symbol")
    end

    it "knows the fixed-symbol attribute has only an atomic column" do
      expect(described_class.amount_component_columns(:fee)).to eq(["fee_atomic"])
    end
  end

  describe "the writer accepts every documented input form" do
    it "accepts an Amount instance" do
      holding.balance = Amount.usdc("12.34")
      expect(holding.balance).to be_amount_of(:USDC)
    end

    it "accepts a compact string" do
      holding.balance = "USDC|12.34"
      expect(holding.balance.decimal).to eq(BigDecimal("12.34"))
    end

    it "accepts a {atomic:, symbol:} hash" do
      holding.balance = { atomic: 12_340_000, symbol: :USDC }
      expect(holding.balance.atomic).to eq(12_340_000)
    end

    it "accepts a {value:, symbol:} hash" do
      holding.balance = { value: "12.34", symbol: :USDC }
      expect(holding.balance.decimal).to eq(BigDecimal("12.34"))
    end

    it "accepts numeric input ONLY for fixed-symbol attributes" do
      holding.fee = 0.5
      expect(holding.fee).to eq_amount("SOL|0.5")
    end

    it "rejects numeric input for multi-symbol attributes via validation" do
      holding.balance = 5
      expect(holding).not_to be_valid
      expect(holding.errors[:balance].join).to match(/raw numeric/)
    end

    it "clears both component columns when assigned nil" do
      holding.balance = "USDC|10"
      holding.balance = nil
      expect(holding.balance).to be_nil
      expect(holding.balance_atomic).to be_nil
      expect(holding.balance_symbol).to be_nil
    end
  end

  describe "structural validations from has_amount" do
    it "rejects an Amount whose symbol does not match the fixed-symbol attribute" do
      holding.fee = Amount.usdc("0.50")
      expect(holding).not_to be_valid
      expect(holding.errors[:fee].join).to match(/expected SOL/i)
    end

    it "requires both atomic and symbol or neither (atomic set, symbol nil)" do
      record = described_class.new(owner: "x", balance_atomic: 100)
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/both atomic and symbol or neither/i)
    end

    it "requires both atomic and symbol or neither (symbol set, atomic nil)" do
      record = described_class.new(owner: "x", balance_symbol: "USDC")
      expect(record).not_to be_valid
      expect(record.errors[:balance].join).to match(/both atomic and symbol or neither/i)
    end

    it "tolerates both columns nil (multi-symbol attribute is optional)" do
      record = described_class.new(owner: "x")
      expect(record.balance).to be_nil
      expect(record).to be_valid
    end
  end

  describe "Type#cast input edge cases (surfaced via writer)" do
    it "treats empty string the same as nil (clears columns)" do
      holding.balance = "USDC|10"
      holding.balance = ""
      expect(holding.balance).to be_nil
      expect(holding.balance_atomic).to be_nil
    end

    it "rejects a hash missing both atomic and value keys" do
      holding.balance = { something: "else" }
      expect(holding).not_to be_valid
      expect(holding.errors[:balance].join).to match(/atomic\/symbol or value\/symbol/)
    end

    it "rejects an unsupported class with a clear message" do
      holding.balance = Object.new
      expect(holding).not_to be_valid
      expect(holding.errors[:balance].join).to match(/cannot cast Object to Amount/)
    end

    it "accepts a {value:, symbol:} hash with string keys" do
      holding.balance = { "value" => "12.34", "symbol" => "USDC" }
      expect(holding.balance).to eq_amount("USDC|12.34")
    end
  end

  describe "AmountValidator (validates :x, amount: { ... })" do
    context "balance with greater_than / less_than_or_equal_to" do
      it "rejects zero" do
        holding.balance = Amount.usdc("0")
        expect(holding).not_to be_valid
        expect(holding.errors[:balance].join).to match(/greater than/)
      end

      it "rejects values above the upper bound" do
        holding.balance = Amount.usdc("1000001")
        expect(holding).not_to be_valid
        expect(holding.errors[:balance].join).to match(/less than/)
      end

      it "accepts the boundary value of less_than_or_equal_to" do
        holding.balance = Amount.usdc("1000000")
        expect(holding).to be_valid
      end
    end

    context "fee with symbol pinning + numeric thresholds (allow_nil)" do
      it "accepts a SOL-symboled non-negative value" do
        holding.fee = Amount.sol("0")
        expect(holding).to be_valid
      end

      it "rejects fee >= 100 SOL" do
        holding.fee = Amount.sol("100")
        expect(holding).not_to be_valid
        expect(holding.errors[:fee].join).to match(/less than/)
      end

      it "skips validation when fee is nil" do
        holding.fee = nil
        expect(holding).to be_valid
      end
    end

    context "reserve has a default and a greater_than_or_equal_to floor" do
      it "starts with the migration-default reserve of $1.25" do
        record = described_class.new(owner: "x")
        expect(record.reserve).to eq_amount("USDC|1.25")
      end

      it "accepts the floor exactly" do
        holding.reserve = Amount.usdc("1.25")
        expect(holding).to be_valid
      end

      it "rejects below floor" do
        holding.reserve = Amount.usdc("1.24")
        expect(holding).not_to be_valid
        expect(holding.errors[:reserve].join).to match(/greater than or equal to/)
      end
    end
  end

  describe "dirty tracking helpers" do
    let!(:persisted) { create(:treasury_holding, balance: "USDC|10.00") }

    it "tracks balance_changed?" do
      persisted.balance = "USDC|11.00"
      expect(persisted.balance_changed?).to be(true)
    end

    it "exposes balance_was as the value-in-database before save" do
      persisted.balance = "USDC|11.00"
      expect(persisted.balance_was).to eq_amount("USDC|10.0")
    end

    it "exposes balance_change as [old, new]" do
      persisted.balance = "USDC|11.00"
      old, new = persisted.balance_change
      expect(old).to eq_amount("USDC|10.0")
      expect(new).to eq_amount("USDC|11.0")
    end

    it "exposes saved_change_to_balance after save" do
      persisted.balance = "USDC|11.00"
      persisted.save!
      old, new = persisted.saved_change_to_balance
      expect(old).to eq_amount("USDC|10.0")
      expect(new).to eq_amount("USDC|11.0")
      expect(persisted.balance_before_last_save).to eq_amount("USDC|10.0")
    end

    it "fires the after_save callback only when the balance actually changed" do
      persisted.balance = "USDC|11.00"
      expect { persisted.save! }.to change { persisted.balance_change_log.size }.by(1)
      expect { persisted.save! }.not_to change { persisted.balance_change_log.size }
    end
  end

  describe "scopes provided by has_amount" do
    let!(:tiny)  { create(:treasury_holding, balance: "USDC|1.00") }
    let!(:small) { create(:treasury_holding, balance: "USDC|10.00") }
    let!(:big)   { create(:treasury_holding, balance: "USDC|10000.00") }
    let!(:sol)   { create(:treasury_holding, :sol_balance) }

    it "where_balance_gt" do
      expect(described_class.where_balance_gt("USDC|5.00")).to contain_exactly(small, big)
    end

    it "where_balance_gte" do
      expect(described_class.where_balance_gte("USDC|10.00")).to contain_exactly(small, big)
    end

    it "where_balance_lt / where_balance_lte" do
      expect(described_class.where_balance_lt("USDC|10.00")).to contain_exactly(tiny)
      expect(described_class.where_balance_lte("USDC|10.00")).to contain_exactly(tiny, small)
    end

    it "where_balance_between" do
      expect(described_class.where_balance_between("USDC|1.00", "USDC|10.00")).to contain_exactly(tiny, small)
    end

    it "balance_in filters by symbol" do
      expect(described_class.balance_in(:USDC)).to contain_exactly(tiny, small, big)
      expect(described_class.balance_in(:SOL)).to contain_exactly(sol)
    end

    it "where_balance auto-filters by symbol on multi-symbol attributes" do
      expect(described_class.where_balance("USDC|10.00")).to contain_exactly(small)
    end

    it "between with cross-symbol bounds raises TypeMismatch" do
      expect { described_class.where_balance_between("USDC|1", "SOL|1") }.to raise_error(Amount::TypeMismatch)
    end

    it "fixed-symbol scopes accept raw numerics directly" do
      sol.update!(fee: Amount.sol("0.75"))
      expect(described_class.where_fee_gt(0.5)).to include(sol)
    end
  end

  describe "user scopes layered on the generated ones" do
    let!(:rich) { create(:treasury_holding, :rich) }
    let!(:poor) { create(:treasury_holding) }

    it "exposes a custom .rich scope" do
      expect(described_class.rich).to contain_exactly(rich)
    end
  end

  describe "match_amounts aggregation matcher" do
    before do
      create(:treasury_holding, balance: "USDC|10")
      create(:treasury_holding, balance: "USDC|1.50")
      create(:treasury_holding, :sol_balance)
    end

    it "matches grouped sums of the atomic columns" do
      sums = described_class.group(:balance_symbol).sum(:balance_atomic)
      expect(sums).to match_amounts(USDC: "11.50", SOL: "12.5")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:transfers).class_name("Treasury::Transfer").dependent(:destroy) }
  end

  describe "#total_in cross-type aggregation" do
    it "sums balance + reserve in the requested target symbol" do
      record = create(:treasury_holding, balance: "USDC|10.00")
      total = record.total_in(:USDC)
      expect(total).to eq_amount("USDC|11.25")
    end
  end
end
