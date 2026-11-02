require "rails_helper"

# =============================================================================
# Auric Vault — end-to-end cookbook scenario
# =============================================================================
#
# Walks through a single bullion bar from ingestion to splitting:
#   - rendering the same weight in oz_t / gram / kg with the right
#     ui_decimals per unit
#   - reading the raw scaled BigDecimal via `in_unit` for arithmetic
#   - using an explicit `.to(:USDC, rate: ...)` for a market quote that
#     bypasses the registered default
#   - splitting a bar in half with no remainder

RSpec.describe "Auric Vault cookbook scenario", :integration, type: :model do
  let!(:bullion) { create(:vault_gold_bar, weight: Amount.of_gold("12.5"), appraisal: "USDC|25000") }

  it "renders weight in oz_t / gram / kg with their respective ui_decimals" do
    expect(bullion.weight_label).to eq("12.5000 oz t")
    expect(bullion.weight_label(unit: :gram)).to eq("388.79 g")
    expect(bullion.weight_label(unit: :kg)).to eq("0.38879 kg")
  end

  it "round-trips a fixed-symbol weight and a multi-symbol appraisal" do
    expect(bullion).to have_amount_column(:weight, "GOLD|12.5")
    expect(bullion).to have_amount_column(:appraisal, "USDC|25000.0")
  end

  it "supports an explicit conversion rate via .to(:USDC, rate: ...)" do
    quote = bullion.weight.to(:USDC, rate: "2000")
    expect(quote).to eq_amount("USDC|25000.0")
  end

  it "reads raw scaled BigDecimal via in_unit" do
    expect(bullion.weight_in(:gram)).to eq(BigDecimal("388.79375"))
  end

  it "splits a vault bar into halves with no remainder" do
    parts, rem = bullion.split_into(2)
    expect(parts.map(&:atomic).sum + rem.atomic).to eq(bullion.weight.atomic)
  end
end

# Locale-aware display: the vault shows the same bar to a US and a German
# desk. Only the number characters change; the stored value and wire format
# do not.
RSpec.describe "Auric Vault localized display", :integration, type: :model do
  let!(:bullion) { create(:vault_gold_bar, weight: Amount.of_gold("12.5"), appraisal: "USDC|25000") }

  after { Amount.localize = false }

  it "leaves labels unchanged without a locale" do
    expect(bullion.weight_label(unit: :gram)).to eq("388.79 g")
    expect(bullion.appraisal_label).to eq("$25000.00")
  end

  it "formats labels for an explicit locale" do
    expect(bullion.weight_label(unit: :gram, locale: :de)).to eq("388,79 Gramm")
    expect(bullion.weight_label(locale: :de)).to eq("12,5000 Feinunzen")
    expect(bullion.weight_label(unit: :kg, locale: :de)).to eq("0,38879 Kilogramm")
    expect(bullion.appraisal_label(locale: :en)).to eq("$25,000.00")
    expect(bullion.appraisal_label(locale: :de)).to eq("25.000,00\u00A0$")
  end

  it "translates unit labels from I18n" do
    weight = bullion.weight
    expect(weight.unit_label(unit: :gram, locale: :de)).to eq("Gramm")
    expect(weight.unit_label(unit: :gram, locale: :en)).to eq("g")
    expect(weight.unit_label(unit: :gram)).to eq("g")
  end

  it "translates every display unit of the same bar" do
    weight = bullion.weight
    labels = %i[oz_t gram kg].to_h { |u| [u, weight.unit_label(unit: u, locale: :de)] }
    expect(labels).to eq(oz_t: "Feinunzen", gram: "Gramm", kg: "Kilogramm")
    expect(%i[oz_t gram kg].map { |u| weight.unit_label(unit: u, locale: :en) }).to eq(["oz t", "g", "kg"])
  end

  it "pluralizes the unit label to agree with the number" do
    one_ounce = Amount.of_gold("1")
    expect(one_ounce.ui(locale: :de)).to eq("1,0000 Feinunze")
    expect(one_ounce.unit_label(locale: :de, count: 1)).to eq("Feinunze")
    expect(bullion.weight.ui(locale: :de)).to eq("12,5000 Feinunzen")
    expect(one_ounce.ui(locale: :en)).to eq("1.0000 oz t")
  end

  it "renders a column header and value separately per locale" do
    weight = bullion.weight
    expect(weight.unit_label(unit: :gram, locale: :de)).to eq("Gramm")
    expect(weight.ui(unit: :gram, locale: :de)).to eq("388,79 Gramm")
    expect(weight.ui(unit: :gram, locale: :en)).to eq("388.79 g")
  end

  it "follows I18n.locale when Amount.localize is on" do
    Amount.localize = true
    I18n.with_locale(:de) { expect(bullion.appraisal_label).to eq("25.000,00\u00A0$") }
    I18n.with_locale(:en) { expect(bullion.appraisal_label).to eq("$25,000.00") }
  end

  it "places the unit with the locale's template, keeping its non-breaking space" do
    expect(bullion.appraisal_label(locale: :de)).to eq("25.000,00\u00A0$")
    expect(bullion.appraisal_label(locale: :en)).to eq("$25,000.00")
    expect(bullion.appraisal.ui(locale: :de, decorated: false)).to eq("25.000,00")
  end

  it "keeps the wire format locale-free" do
    Amount.localize = true
    I18n.with_locale(:de) do
      expect(bullion.appraisal.to_s).to eq("USDC|25000.00")
      expect(bullion).to have_amount_column(:appraisal, "USDC|25000.0")
    end
  end

  it "formats large and negative values with grouping" do
    expect(Amount.of_usdc("-1234567.5").ui(locale: :de)).to eq("-1.234.567,50\u00A0$")
  end
end
