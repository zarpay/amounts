require "rails_helper"

# =============================================================================
# Manifest endpoint — the registry, exported for the JavaScript client
# =============================================================================
#
# GET /amounts/manifest serves Amount.manifest for every shipped locale. The
# @zarpay/amounts client is built from exactly this JSON, so these examples
# pin what a frontend receives from the demo's real registry and locale files.

RSpec.describe "GET /amounts/manifest" do
  include_context "with the application registry"

  let(:manifest) { response.parsed_body }

  before { get "/amounts/manifest" }

  it "responds with JSON" do
    expect(response.media_type).to eq("application/json")
  end

  it "serves manifest version 1" do
    expect(manifest["v"]).to eq(1)
  end

  it "lists every registered type" do
    expect(manifest["types"].keys).to match_array(Amount.registry.symbols.map(&:to_s))
  end

  it "writes a type with the register option names" do
    expect(manifest["types"]["USDC"]).to include("decimals" => 6, "display_symbol" => "$", "display_format" => "%u%n")
  end

  it "writes a display unit's scale as an exact string" do
    expect(manifest["types"]["GOLD"]["display_units"]["gram"]["scale"]).to eq(
      Amount.coerce_decimal(Amount.registry.lookup(:GOLD).display_unit(:gram)[:scale]).to_s("F")
    )
  end

  it "serves every directional default rate" do
    expect(manifest["rates"].size).to eq(Amount.registry.default_rates.size)
  end

  it "resolves every shipped locale" do
    expect(manifest["locales"].keys).to match_array(I18n.available_locales.map(&:to_s))
  end

  it "writes German number formats" do
    expect(manifest["locales"]["de"]["number"]).to eq("delimiter" => ".", "separator" => ",")
  end

  it "writes a German plural label whole" do
    expect(manifest["locales"]["de"]["types"]["GOLD"]["label"]).to eq("one" => "Feinunze", "other" => "Feinunzen")
  end

  it "writes a German template" do
    expect(manifest["locales"]["de"]["types"]["USDC"]["format"]).to eq("%n %u")
  end

  it "writes a German compact word" do
    expect(manifest["locales"]["de"]["compact"]["units"]["million"]).to eq("Mio.")
  end

  it "is exactly Amount.manifest for the shipped locales" do
    expect(manifest).to eq(JSON.parse(Amount.manifest(locales: I18n.available_locales).to_json))
  end
end
