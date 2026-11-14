# frozen_string_literal: true

require "json"
require_relative "../test_helper"
require_relative "../support/locale_test_setup"

class AmountManifestTest < Minitest::Test
  include LocaleTestSetup

  # Types

  def test_version_is_one
    assert_equal 1, manifest["v"]
  end

  def test_types_are_keyed_by_symbol
    assert_equal %w[USDC USD SOL GOLD LOGS], manifest["types"].keys
  end

  def test_type_decimals
    assert_equal 6, type("USDC")["decimals"]
  end

  def test_type_display_symbol
    assert_equal "$", type("USDC")["display_symbol"]
  end

  def test_type_plural_display_symbol_has_string_keys
    Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search", other: "searches" }

    assert_equal({ "one" => "search", "other" => "searches" }, type("SEARCHES")["display_symbol"])
  end

  def test_type_display_format_is_the_resolved_template
    assert_equal "%u%n", type("USDC")["display_format"]
  end

  def test_type_display_format_written_as_given
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%n %u"

    assert_equal "%n %u", type("EUR")["display_format"]
  end

  def test_type_ui_decimals
    assert_equal 2, type("USDC")["ui_decimals"]
  end

  def test_type_trim_zeros_defaults_to_false
    assert_equal false, type("USDC")["trim_zeros"]
  end

  def test_type_trim_zeros_when_set
    Amount.register :TOKENS, decimals: 0, trim_zeros: true

    assert_equal true, type("TOKENS")["trim_zeros"]
  end

  def test_type_without_display_units
    assert_nil type("USDC")["display_units"]
  end

  def test_type_default_display
    assert_equal "oz_t", type("GOLD")["default_display"]
  end

  def test_type_without_default_display
    assert_nil type("USDC")["default_display"]
  end

  # Display units

  def test_display_units_are_keyed_by_unit
    assert_equal %w[oz_t gram kg], type("GOLD")["display_units"].keys
  end

  def test_display_unit_scale_is_an_exact_string
    assert_equal "31.1035", unit("GOLD", "gram")["scale"]
  end

  def test_display_unit_integer_scale
    assert_equal "1.0", unit("GOLD", "oz_t")["scale"]
  end

  def test_display_unit_rational_scale_is_written_as_the_gem_uses_it
    register_unit_type(third: { scale: Rational(1, 3) })

    assert_equal "0.3333333333333333333", unit("UNITS", "third")["scale"]
  end

  def test_display_unit_symbol
    assert_equal "g", unit("GOLD", "gram")["symbol"]
  end

  def test_display_unit_without_symbol
    register_unit_type(plain: { scale: 1 })

    assert_nil unit("UNITS", "plain")["symbol"]
  end

  def test_display_unit_ui_decimals
    assert_equal 2, unit("GOLD", "gram")["ui_decimals"]
  end

  def test_display_unit_without_ui_decimals
    register_unit_type(plain: { scale: 1 })

    assert_nil unit("UNITS", "plain")["ui_decimals"]
  end

  def test_display_unit_format
    register_unit_type(dozen: { scale: "0.083", format: "%n doz" })

    assert_equal "%n doz", unit("UNITS", "dozen")["format"]
  end

  def test_display_unit_position_is_written_as_its_template
    register_unit_type(dozen: { scale: "0.083", position: :prefix })

    assert_equal "%u%n", unit("UNITS", "dozen")["format"]
  end

  def test_display_unit_without_format_or_position
    assert_nil unit("GOLD", "gram")["format"]
  end

  def test_display_unit_trim_zeros_when_set
    register_unit_type(plain: { scale: 1, trim_zeros: true })

    assert_equal true, unit("UNITS", "plain")["trim_zeros"]
  end

  def test_display_unit_trim_zeros_set_to_false
    register_unit_type(plain: { scale: 1, trim_zeros: false })

    assert_equal false, unit("UNITS", "plain")["trim_zeros"]
  end

  def test_display_unit_without_trim_zeros
    assert_nil unit("GOLD", "gram")["trim_zeros"]
  end

  # Rates

  def test_without_rates
    assert_empty manifest["rates"]
  end

  def test_rate_row
    Amount.register_default_rate :USD, :USDC, "1"

    assert_equal [{ "from" => "USD", "to" => "USDC", "rate" => "1.0" }], manifest["rates"]
  end

  def test_rational_rate_is_written_as_the_gem_uses_it
    Amount.register_default_rate :USDC, :USD, Rational(1, 3)

    assert_equal "0.3333333333333333333", manifest["rates"].first["rate"]
  end

  # Locales

  def test_without_locales
    assert_empty manifest["locales"]
  end

  def test_locales_are_keyed_by_locale
    assert_equal %w[en de], manifest(locales: %i[en de])["locales"].keys
  end

  def test_locales_need_i18n
    without_i18n do
      assert_raises(ArgumentError) { manifest(locales: [:de]) }
    end
  end

  def test_number_format
    assert_equal({ "delimiter" => ".", "separator" => "," }, locale_table(:de)["number"])
  end

  def test_number_format_defaults
    assert_equal({ "delimiter" => ",", "separator" => "." }, locale_table(:xx)["number"])
  end

  def test_compact_format_defaults
    assert_equal "%n %u", locale_table(:de)["compact"]["format"]
  end

  def test_compact_format_translated
    store(:de, number: { human: { decimal_units: { format: "%n%u" } } })

    assert_equal "%n%u", locale_table(:de)["compact"]["format"]
  end

  def test_compact_format_without_number_falls_back
    store(:de, number: { human: { decimal_units: { format: "%u" } } })

    assert_equal "%n %u", locale_table(:de)["compact"]["format"]
  end

  def test_compact_units_list_every_scale
    assert_equal %w[thousand million billion trillion quadrillion quintillion sextillion septillion
                    octillion nonillion decillion], locale_table(:de)["compact"]["units"].keys
  end

  def test_compact_unit_translated
    store(:de, number: { human: { decimal_units: { units: { thousand: "Tsd." } } } })

    assert_equal "Tsd.", locale_table(:de)["compact"]["units"]["thousand"]
  end

  def test_compact_unit_plural_forms
    store(:de, number: { human: { decimal_units: { units: { million: { one: "Million", other: "Millionen" } } } } })

    assert_equal({ "one" => "Million", "other" => "Millionen" }, locale_table(:de)["compact"]["units"]["million"])
  end

  def test_compact_unit_without_translation
    assert_nil locale_table(:de)["compact"]["units"]["thousand"]
  end

  def test_type_label_without_translation
    assert_nil locale_type(:de, "GOLD")["label"]
  end

  def test_type_label_translated
    store(:de, amounts: { units: { gold: "Feinunze" } })

    assert_equal "Feinunze", locale_type(:de, "GOLD")["label"]
  end

  def test_type_label_from_label_key
    store(:de, coins: { searches: "Suchen" })
    Amount.register :SEARCHES, decimals: 0, label_key: "coins.searches"

    assert_equal "Suchen", locale_type(:de, "SEARCHES")["label"]
  end

  def test_type_label_plural_forms
    store(:de, amounts: { units: { logs: { one: "Stamm", other: "Stämme" } } })

    assert_equal({ "one" => "Stamm", "other" => "Stämme" }, locale_type(:de, "LOGS")["label"])
  end

  def test_type_format_translated
    store(:de, amounts: { formats: { usd: "%n %u" } })

    assert_equal "%n %u", locale_type(:de, "USD")["format"]
  end

  def test_type_format_without_number_is_ignored
    store(:de, amounts: { formats: { usd: "%u" } })

    assert_nil locale_type(:de, "USD")["format"]
  end

  def test_type_without_display_units_has_no_unit_tables
    assert_empty locale_type(:de, "USD")["units"]
  end

  def test_unit_label_translated
    store(:de, amounts: { display_units: { gold: { gram: "Gramm" } } })

    assert_equal "Gramm", locale_type(:de, "GOLD")["units"]["gram"]["label"]
  end

  def test_unit_label_from_label_key
    store(:de, metric: { gram: "Gramm" })
    register_unit_type(gram: { scale: 1, label_key: "metric.gram" })

    assert_equal "Gramm", locale_type(:de, "UNITS")["units"]["gram"]["label"]
  end

  def test_unit_label_without_translation
    assert_nil locale_type(:de, "GOLD")["units"]["gram"]["label"]
  end

  def test_unit_format_translated
    store(:de, amounts: { display_unit_formats: { gold: { gram: "%n %u" } } })

    assert_equal "%n %u", locale_type(:de, "GOLD")["units"]["gram"]["format"]
  end

  def test_unit_format_without_translation
    assert_nil locale_type(:de, "GOLD")["units"]["gram"]["format"]
  end

  # JSON

  def test_survives_a_json_round_trip
    Amount.register_default_rate :USD, :USDC, "1"
    written = manifest(locales: [:de])

    assert_equal written, JSON.parse(written.to_json)
  end

  private

  def manifest(locales: [])
    Amount::Manifest.new(Amount.registry, locales:).to_h
  end

  def type(symbol)
    manifest["types"][symbol]
  end

  def unit(symbol, unit)
    type(symbol)["display_units"][unit]
  end

  def locale_table(locale)
    manifest(locales: [locale])["locales"][locale.to_s]
  end

  def locale_type(locale, symbol)
    locale_table(locale)["types"][symbol]
  end

  def store(locale, translations)
    I18n.backend.store_translations(locale, translations)
  end

  def register_unit_type(units)
    Amount.register :UNITS, decimals: 2, display_units: units
  end
end
