require "rails_helper"

# =============================================================================
# Custom-class amount — full surface coverage
# =============================================================================
#
# This file is the "everything works for custom-class symbols" regression
# guard. It registers a fresh symbol :BUL with `class: BullionAmount`,
# wires up an ActiveRecord model on a temporary table, and then exercises
# every operation that a non-custom amount supports: construction,
# arithmetic, comparison, conversion, AR write/read, AR queries, AR
# aggregations, validation.
#
# Pre-0.0.2 the AR adapter could not read a custom-class amount back out
# at all (Type#deserialize raised). This spec is the proof that the fix
# is comprehensive — if any of these examples regress, the gem broke
# something it shouldn't have.
class BullionAmount < Amount
  def half_purity
    decimal / 2
  end
end

unless Amount.registry.registered?(:BUL)
  Amount.register :BUL, decimals: 4, display_symbol: "BUL", display_position: :suffix, ui_decimals: 4, class: BullionAmount
  Amount.register_default_rate :BUL, :USD, "100"
  Amount.register_default_rate :USD, :BUL, "0.01"
end

unless ActiveRecord::Base.connection.table_exists?(:bullion_holdings)
  ActiveRecord::Schema.define do
    create_table :bullion_holdings, force: true do |t|
      t.amount :weight, symbol: :BUL, null: false
      t.amount :appraisal, null: true
      t.timestamps null: false
    end
  end
end

class BullionHolding < ApplicationRecord
  self.table_name = "bullion_holdings"
  has_amount :weight, symbol: :BUL
  has_amount :appraisal
  validates :weight, amount: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :appraisal, amount: { greater_than: 0, allow_nil: true }
end

RSpec.describe "Custom-class amount full surface", :integration do

  describe "construction" do
    it "Amount.new for :BUL returns a BullionAmount" do
      expect(Amount.new("1", :BUL)).to be_a(BullionAmount)
    end

    it "Amount.parse for BUL returns a BullionAmount" do
      expect(Amount.parse("BUL|1.5")).to be_a(BullionAmount)
    end

    it "Amount.load for BUL returns a BullionAmount" do
      restored = Amount.load(BullionAmount.new("1", :BUL).to_h)
      expect(restored).to be_a(BullionAmount)
    end

    it "the generated constructor still returns the subclass" do
      expect(Amount.of_bul("1")).to be_a(BullionAmount)
    end
  end

  describe "arithmetic preserves subclass identity" do
    let(:a) { Amount.new("3", :BUL) }
    let(:b) { Amount.new("1.5", :BUL) }

    it "addition" do
      expect((a + b).class).to eq(BullionAmount)
      expect(a + b).to eq_amount("BUL|4.5")
    end

    it "subtraction" do
      expect((a - b).class).to eq(BullionAmount)
      expect(a - b).to eq_amount("BUL|1.5")
    end

    it "scalar multiplication" do
      expect((a * 2).class).to eq(BullionAmount)
      expect(a * 2).to eq_amount("BUL|6")
    end

    it "scalar division" do
      expect((a / 2).class).to eq(BullionAmount)
    end

    it "Amount/Amount division still returns BigDecimal" do
      expect(a / b).to eq(BigDecimal("2"))
    end

    it "abs preserves class" do
      expect((-a).abs.class).to eq(BullionAmount)
    end

    it "unary minus preserves class" do
      expect((-a).class).to eq(BullionAmount)
    end

    it "split preserves class" do
      parts, rem = a.split(2)
      expect(parts).to all(be_a(BullionAmount))
      expect(rem).to be_a(BullionAmount)
    end

    it "allocate preserves class" do
      parts, rem = a.allocate([1, 2])
      expect(parts).to all(be_a(BullionAmount))
      expect(rem).to be_a(BullionAmount)
    end

    it "subclass-defined methods survive arithmetic" do
      expect((a + b).half_purity).to eq(BigDecimal("2.25"))
    end
  end

  describe "comparison" do
    it "==/eql? on Amount.new-constructed instances" do
      a = Amount.new("1", :BUL)
      b = Amount.new("1", :BUL)
      expect(a == b).to be(true)
      expect(a.eql?(b)).to be(true)
      expect(a.hash).to eq(b.hash)
    end

    it "Comparable sort works" do
      sorted = [Amount.new("3", :BUL), Amount.new("1", :BUL), Amount.new("2", :BUL)].sort
      expect(sorted.map(&:decimal)).to eq([BigDecimal("1"), BigDecimal("2"), BigDecimal("3")])
    end

    it "cross-type <=> via registered rate" do
      expect(Amount.new("1", :BUL) <=> Amount.of_usd("99")).to eq(1)
      expect(Amount.new("1", :BUL) <=> Amount.of_usd("100")).to eq(0)
      expect(Amount.new("1", :BUL) <=> Amount.of_usd("101")).to eq(-1)
    end
  end

  describe "conversion" do
    it "BUL.to(:USD) returns plain Amount (USD has no custom class)" do
      converted = Amount.new("1", :BUL).to(:USD)
      expect(converted.class).to eq(Amount)
      expect(converted).to eq_amount("USD|100.0")
    end

    it "USD.to(:BUL) returns BullionAmount" do
      converted = Amount.of_usd("100").to(:BUL)
      expect(converted).to be_a(BullionAmount)
      expect(converted).to eq_amount("BUL|1.0")
    end

    it "explicit rate in to() also returns the registered class" do
      converted = Amount.of_usd("50").to(:BUL, rate: "0.02")
      expect(converted).to be_a(BullionAmount)
    end

    it "identity conversion preserves class" do
      a = Amount.new("1", :BUL)
      expect(a.to(:BUL).class).to eq(BullionAmount)
    end
  end

  describe "ActiveRecord round-trip" do
    let(:record) { BullionHolding.create!(weight: BullionAmount.new("2.5", :BUL), appraisal: "USD|250.00") }

    it "writes and reads the custom-class fixed-symbol attribute" do
      record.reload
      expect(record.weight).to be_a(BullionAmount)
      expect(record.weight.decimal).to eq(BigDecimal("2.5"))
    end

    it "writes via Amount.new for :BUL (auto-dispatches)" do
      h = BullionHolding.new(weight: Amount.new("1.0", :BUL))
      expect(h.weight).to be_a(BullionAmount)
      h.save!
      expect(BullionHolding.find(h.id).weight).to be_a(BullionAmount)
    end

    it "writes via compact-string casting" do
      h = BullionHolding.new(weight: "BUL|1.5")
      h.save!
      expect(BullionHolding.find(h.id).weight).to be_a(BullionAmount)
    end

    it "writes via {atomic:, symbol:} hash" do
      h = BullionHolding.new(weight: { atomic: 15_000, symbol: :BUL })
      h.save!
      expect(BullionHolding.find(h.id).weight).to be_a(BullionAmount)
    end

    it "writes via raw numeric (fixed-symbol path)" do
      h = BullionHolding.new(weight: 1.5)
      h.save!
      expect(BullionHolding.find(h.id).weight).to be_a(BullionAmount)
    end

    it "dirty tracking exposes BullionAmount instances" do
      record.weight = BullionAmount.new("3", :BUL)
      old, new = record.weight_change
      expect(old).to be_a(BullionAmount)
      expect(new).to be_a(BullionAmount)
    end
  end

  describe "ActiveRecord queries" do
    before do
      BullionHolding.delete_all
      @small  = BullionHolding.create!(weight: BullionAmount.new("0.5", :BUL))
      @medium = BullionHolding.create!(weight: BullionAmount.new("2", :BUL))
      @large  = BullionHolding.create!(weight: BullionAmount.new("10", :BUL))
    end

    it "where_weight equality" do
      expect(BullionHolding.where_weight("BUL|2.0")).to contain_exactly(@medium)
    end

    it "where_weight_gt" do
      expect(BullionHolding.where_weight_gt("BUL|1.0")).to contain_exactly(@medium, @large)
    end

    it "where_weight_lte" do
      expect(BullionHolding.where_weight_lte("BUL|2.0")).to contain_exactly(@small, @medium)
    end

    it "where_weight_between" do
      expect(BullionHolding.where_weight_between("BUL|1.0", "BUL|9.0")).to contain_exactly(@medium)
    end

    it "fixed-symbol scope accepts a raw numeric" do
      expect(BullionHolding.where_weight_gt(1.0)).to contain_exactly(@medium, @large)
    end

    it "match_amounts aggregation works on custom-class symbols" do
      total_atomic = BullionHolding.sum(:weight_atomic)
      expect(BullionAmount.new(total_atomic, :BUL, from: :atomic).decimal).to eq(BigDecimal("12.5"))
    end
  end

  describe "validation" do
    it "rejects weight = 0 via numeric threshold" do
      h = BullionHolding.new(weight: BullionAmount.new(0, :BUL, from: :atomic))
      expect(h).not_to be_valid
      expect(h.errors[:weight].join).to match(/greater than/)
    end

    it "rejects weight above the upper bound" do
      h = BullionHolding.new(weight: BullionAmount.new("101", :BUL))
      expect(h).not_to be_valid
    end

    it "accepts a multi-symbol numeric appraisal threshold" do
      h = BullionHolding.new(weight: BullionAmount.new("1", :BUL), appraisal: "USD|0")
      expect(h).not_to be_valid
      expect(h.errors[:appraisal].join).to match(/greater than/)
    end
  end
end
