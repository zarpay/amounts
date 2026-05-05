require "rails_helper"

# =============================================================================
# Vault::GoldBar spec — display units + custom subclass round-trip
# =============================================================================
#
# This spec is the harness's home for the Auric cookbook's central lessons:
#
#   - GOLD's display_units (oz_t default, gram, kg) all render correctly
#     through the model's `weight_label` wrapper in both rounding directions
#
#   - `weight_in(:gram)` returns the raw scaled BigDecimal (no rounding,
#     no symbol) for callers that want to compose with arithmetic
#
#   - the `class: GoldAmount` registration round-trips through the
#     ActiveRecord adapter — every read returns a real GoldAmount
#     instance, with `purity_for(...)` callable on it
#
#   - subclass identity survives arithmetic on persisted weights
#
#   - `split_into` and `allocate_by` preserve the parts/remainder invariant
#
#   - `match_amounts` aggregation works when the appraisal currency varies
#     across rows
#
#   - shoulda-matchers cover serial presence + uniqueness, matching the
#     migration's NOT NULL + unique index

RSpec.describe Vault::GoldBar, type: :model do
  subject(:bar) { build(:vault_gold_bar) }

  describe "schema" do
    it "stores weight as a fixed-symbol GOLD attribute" do
      expect(described_class.amount_component_columns(:weight)).to eq(["weight_atomic"])
      expect(described_class.amount_attribute_definitions[:weight].symbol).to eq(:GOLD)
    end

    it "stores appraisal as a multi-symbol attribute" do
      expect(described_class.amount_component_columns(:appraisal)).to eq(["appraisal_atomic", "appraisal_symbol"])
    end
  end

  describe "custom GoldAmount subclass round-trip (fixed in amounts 0.0.2)" do
    let!(:persisted) { create(:vault_gold_bar, weight: Amount.of_gold("3.5")) }

    it "reads back as a GoldAmount instance, not a plain Amount" do
      reloaded = described_class.find(persisted.id)
      expect(reloaded.weight).to be_a(GoldAmount)
    end

    it "exposes subclass-defined methods on the reader" do
      reloaded = described_class.find(persisted.id)
      expect(reloaded.weight.purity_for("18k")).to eq(BigDecimal("3.5") * BigDecimal("0.750"))
    end

    it "preserves subclass identity through arithmetic on the persisted weight" do
      reloaded = described_class.find(persisted.id)
      expect((reloaded.weight + Amount.of_gold("0.5")).class).to eq(GoldAmount)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:serial) }
    it { is_expected.to validate_uniqueness_of(:serial) }

    it "rejects zero weight" do
      bar.weight = Amount.of_gold(0, from: :atomic)
      expect(bar).not_to be_valid
      expect(bar.errors[:weight].join).to match(/greater than/)
    end
  end

  describe "display unit features" do
    let(:big) { build(:vault_gold_bar, :heavy) }

    it "renders ui in default oz_t unit" do
      expect(big.weight_label).to eq("100.0000 oz t")
    end

    it "renders ui in :gram unit" do
      expect(big.weight_label(unit: :gram)).to eq("3110.35 g")
    end

    it "renders ui in :kg unit with 5 decimals" do
      expect(big.weight_label(unit: :kg)).to eq("3.11035 kg")
    end

    it "supports :ceil rounding direction" do
      bar.weight = Amount.of_gold("1.00001")
      expect(bar.weight_label(direction: :ceil)).to eq("1.0001 oz t")
    end

    it "exposes raw scaled BigDecimal via in_unit" do
      expect(big.weight_in(:gram)).to eq(BigDecimal("3110.35"))
    end

    it "raises InvalidDisplayUnit for an unknown unit" do
      expect { bar.weight_label(unit: :ounce) }.to raise_error(Amount::Registry::InvalidDisplayUnit)
    end
  end

  describe "split / allocate" do
    let(:bar) { build(:vault_gold_bar, weight: Amount.of_gold("3")) }

    it "splits into N equal parts with remainder" do
      parts, rem = bar.split_into(2)
      expect(parts.map(&:atomic).sum + rem.atomic).to eq(bar.weight.atomic)
    end

    it "allocates by weights" do
      parts, _rem = bar.allocate_by([1, 1, 2])
      expect(parts.size).to eq(3)
    end
  end

  describe "appraisal cross-symbol attribute" do
    it "stores appraisal in any registered currency" do
      bar.appraisal = Amount.of_usd("2000")
      bar.save!
      bar.reload
      expect(bar.appraisal).to eq_amount("USD|2000.0")
    end
  end

  describe "match_amounts grouping by appraisal_symbol" do
    before do
      create(:vault_gold_bar, weight: Amount.of_gold("1"), appraisal: "USDC|2000")
      create(:vault_gold_bar, weight: Amount.of_gold("1"), appraisal: "USDC|2500")
      create(:vault_gold_bar, weight: Amount.of_gold("1"), appraisal: Amount.of_usd("2100"))
    end

    it "aggregates appraisal by symbol" do
      sums = described_class.group(:appraisal_symbol).sum(:appraisal_atomic)
      expect(sums).to match_amounts(USDC: "4500", USD: "2100")
    end
  end
end
