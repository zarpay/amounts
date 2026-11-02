# frozen_string_literal: true

require "i18n"
require_relative "../test_helper"
require_relative "../support/locale_test_setup"

class AmountLocaleTest < Minitest::Test
  include LocaleTestSetup

  # Not localizing

  def test_not_localizing_keeps_the_plain_number
    assert_equal "$122500.00", Amount.of_usd("122500").ui
  end

  def test_not_localizing_keeps_a_negative_number_plain
    assert_equal "-$1234.50".sub("$", ""), Amount.of_usd("-1234.50").ui.sub("$", "")
  end

  def test_not_localizing_keeps_a_zero_decimal_type_plain
    assert_equal "1500 logs", Amount.of_logs(1500).ui
  end

  def test_localize_is_off_by_default
    refute_predicate Amount, :localize?
  end

  # The locale: option

  {
    en: "$122,500.00",
    de: "$122.500,00",
    fr: "$122 500,00"
  }.each do |locale, expected|
    define_method("test_locale_option_formats_#{locale}") do
      assert_equal expected, Amount.of_usd("122500").ui(locale:)
    end
  end

  def test_locale_under_one_thousand_has_no_delimiter
    assert_equal "$999,99", Amount.of_usd("999.99").ui(locale: :de)
  end

  def test_locale_negative_millions_in_de
    assert_equal "$-1.234.567,50", Amount.of_usd("-1234567.50").ui(locale: :de)
  end

  def test_locale_negative_thousands_in_en
    assert_equal "$-1,234.50", Amount.of_usd("-1234.50").ui(locale: :en)
  end

  def test_locale_negative_under_one_thousand_in_en
    assert_equal "$-123.00", Amount.of_usd("-123").ui(locale: :en)
  end

  def test_locale_with_decimals_zero_type_in_en
    assert_equal "1,500 logs", Amount.of_logs(1500).ui(locale: :en)
  end

  def test_locale_with_decimals_zero_type_in_de
    assert_equal "1.500.000 logs", Amount.of_logs(1_500_000).ui(locale: :de)
  end

  def test_locale_with_trim_zeros_keeps_significant_decimals
    assert_equal "1.234,5 SOL", Amount.of_sol("1234.5").ui(locale: :de, trim_zeros: true)
  end

  def test_locale_with_trim_zeros_drops_all_zero_decimals
    assert_equal "1.000 SOL", Amount.of_sol("1000").ui(locale: :de, trim_zeros: true)
  end

  def test_locale_rounds_down_by_default
    assert_equal "$1.234,56", Amount.of_usdc("1234.5678").ui(locale: :de)
  end

  def test_locale_with_ceil_direction
    assert_equal "$1.234,57", Amount.of_usdc("1234.5678").ui(locale: :de, direction: :ceil)
  end

  def test_locale_with_display_unit
    assert_equal "31.103,50 g", Amount.of_gold("1000").ui(unit: :gram, locale: :de)
  end

  def test_locale_with_display_unit_undecorated
    assert_equal "31,103.50", Amount.of_gold("1000").ui(unit: :gram, decorated: false, locale: :en)
  end

  def test_locale_undecorated
    assert_equal "1.000,0000", Amount.of_gold("1000").ui(decorated: false, locale: :de)
  end

  # Amount.localize

  def test_localize_uses_i18n_locale
    localize_in_german

    assert_equal "$1.500,00", Amount.of_usd("1500").ui
  end

  def test_locale_option_overrides_i18n_locale_when_localizing
    localize_in_german

    assert_equal "$1,500.00", Amount.of_usd("1500").ui(locale: :en)
  end

  def test_missing_number_format_falls_back_to_defaults
    assert_equal "$1,500.00", Amount.of_usd("1500").ui(locale: :xx)
  end

  def test_missing_delimiter_falls_back_while_separator_is_used
    I18n.backend.store_translations(:xx, number: { format: { separator: "," } })

    assert_equal "$1,500,00", Amount.of_usd("1500").ui(locale: :xx)
  end

  def test_wire_to_s_does_not_change_when_localizing
    localize_in_german

    assert_equal "USD|122500.50", Amount.of_usd("122500.5").to_s
  end

  def test_wire_formatted_does_not_change_when_localizing
    localize_in_german

    assert_equal "122500.50", Amount.of_usd("122500.5").formatted
  end

  def test_wire_parse_round_trips_when_localizing
    localize_in_german

    assert_equal Amount.of_usd("122500.5"), Amount.parse(Amount.of_usd("122500.5").to_s)
  end

  # Type labels

  def test_type_label_fallback_ui_uses_display_symbol_when_nothing_is_translated
    register_label_fallback_types

    assert_equal "3 searches-sym", Amount.new(3, :SEARCHES).ui(locale: :en)
  end

  def test_type_label_fallback_unit_label_uses_display_symbol_when_nothing_is_translated
    register_label_fallback_types

    assert_equal "searches-sym", Amount.new(3, :SEARCHES).unit_label(locale: :en)
  end

  def test_type_label_fallback_ui_uses_the_conventional_key
    register_label_fallback_types
    store_conventional_unit_labels

    assert_equal "3 searches", Amount.new(3, :SEARCHES).ui(locale: :en)
  end

  def test_type_label_fallback_unit_label_uses_the_conventional_key
    register_label_fallback_types
    store_conventional_unit_labels

    assert_equal "searches", Amount.new(3, :SEARCHES).unit_label(locale: :en)
  end

  def test_type_label_fallback_missing_label_key_skips_the_conventional_key
    register_label_fallback_types
    store_conventional_unit_labels

    assert_equal "3 cr", Amount.new(3, :CREDITS).ui(locale: :en)
  end

  def test_type_label_fallback_label_key_wins_over_the_conventional_key
    register_label_fallback_types
    store_conventional_unit_labels
    I18n.backend.store_translations(:en, custom: { credits: "credits" })

    assert_equal "3 credits", Amount.new(3, :CREDITS).ui(locale: :en)
  end

  def test_two_locales_two_labels_in_en
    register_searches_in_en_and_de

    assert_equal "1,500 searches", Amount.new(1500, :SEARCHES).ui(locale: :en)
  end

  def test_two_locales_two_labels_in_de
    register_searches_in_en_and_de

    assert_equal "1.500 Suchen", Amount.new(1500, :SEARCHES).ui(locale: :de)
  end

  def test_two_locales_two_labels_unit_label_in_de
    register_searches_in_en_and_de

    assert_equal "Suchen", Amount.new(1500, :SEARCHES).unit_label(locale: :de)
  end

  def test_labels_unchanged_in_ui_when_not_localizing
    register_translated_searches

    assert_equal "3 SEARCHES", Amount.new(3, :SEARCHES).ui
  end

  def test_unit_label_unchanged_when_not_localizing
    register_translated_searches

    assert_equal "SEARCHES", Amount.new(3, :SEARCHES).unit_label
  end

  def test_display_unit_label_unchanged_when_not_localizing
    register_translated_searches

    assert_equal "g", Amount.of_gold("1").unit_label(unit: :gram)
  end

  def test_localize_uses_i18n_locale_for_labels_in_ui
    register_german_searches_and_localize

    assert_equal "3 Suchen", Amount.new(3, :SEARCHES).ui
  end

  def test_localize_uses_i18n_locale_for_unit_label
    register_german_searches_and_localize

    assert_equal "Suchen", Amount.new(3, :SEARCHES).unit_label
  end

  # Display unit labels

  def test_display_unit_label_fallback_ui_uses_the_unit_symbol
    assert_equal "31.103,50 g", Amount.of_gold("1000").ui(unit: :gram, locale: :de)
  end

  def test_display_unit_label_fallback_unit_label_uses_the_unit_symbol
    assert_equal "g", Amount.of_gold("1000").unit_label(unit: :gram, locale: :de)
  end

  def test_display_unit_label_fallback_ui_uses_the_conventional_key
    store_german_gram_label

    assert_equal "31.103,50 Gramm", Amount.of_gold("1000").ui(unit: :gram, locale: :de)
  end

  def test_display_unit_label_fallback_unit_label_uses_the_conventional_key
    store_german_gram_label

    assert_equal "Gramm", Amount.of_gold("1000").unit_label(unit: :gram, locale: :de)
  end

  def test_display_unit_label_fallback_other_locale_keeps_the_unit_symbol
    store_german_gram_label

    assert_equal "g", Amount.of_gold("1000").unit_label(unit: :gram, locale: :en)
  end

  def test_display_unit_without_symbol_or_key_uses_the_type_label
    register_mass_with_label_key

    assert_equal "mass", Amount.new("1", :MASS).unit_label(unit: :plain, locale: :en)
  end

  def test_display_unit_with_missing_label_key_uses_the_type_label
    register_mass_with_label_key

    assert_equal "mass", Amount.new("1", :MASS).unit_label(unit: :kilo, locale: :en)
  end

  def test_display_unit_without_symbol_uses_the_translated_type_label
    register_mass_with_label_key
    I18n.backend.store_translations(:en, amounts: { units: { mass: "Mass" } })

    assert_equal "Mass", Amount.new("1", :MASS).unit_label(unit: :plain, locale: :en)
  end

  def test_display_unit_label_key_is_used_when_translated
    register_mass_with_label_key
    I18n.backend.store_translations(:en, amounts: { units: { mass: "Mass" } })
    I18n.backend.store_translations(:en, my: { kilo: "kg" })

    assert_equal "1.00 kg", Amount.new("1", :MASS).ui(unit: :kilo, locale: :en)
  end

  # Plural labels

  def test_hash_label_without_i18n_singular
    without_i18n do
      register_plural_searches

      assert_equal "1 search", Amount.new(1, :SEARCHES).ui
    end
  end

  def test_hash_label_without_i18n_zero_is_plural
    without_i18n do
      register_plural_searches

      assert_equal "0 searches", Amount.new(0, :SEARCHES).ui
    end
  end

  def test_hash_label_without_i18n_plural
    without_i18n do
      register_plural_searches

      assert_equal "2 searches", Amount.new(2, :SEARCHES).ui
    end
  end

  def test_hash_label_without_i18n_unit_label_with_count
    without_i18n do
      register_plural_searches

      assert_equal "search", Amount.new(2, :SEARCHES).unit_label(count: 1)
    end
  end

  def test_hash_label_without_i18n_unit_label_defaults_to_other
    without_i18n do
      register_plural_searches

      assert_equal "searches", Amount.new(1, :SEARCHES).unit_label
    end
  end

  def test_hash_label_counts_the_displayed_one
    register_plural_searches(decimals: 2)

    assert_equal "1.00 search", Amount.new(100, :SEARCHES).ui
  end

  def test_hash_label_counts_a_trimmed_fraction_as_plural
    register_plural_searches(decimals: 2)

    assert_equal "1.5 searches", Amount.new(150, :SEARCHES).ui(trim_zeros: true)
  end

  def test_hash_label_counts_the_displayed_one_in_a_locale
    register_plural_searches(decimals: 2)

    assert_equal "1.00 search", Amount.new(100, :SEARCHES).ui(locale: :fr).sub(",", ".")
  end

  def test_hash_label_counts_the_floored_displayed_number
    register_rated

    assert_equal "1.0 star", Amount.new(104, :RATED).ui
  end

  def test_hash_label_counts_the_ceiled_displayed_number
    register_rated

    assert_equal "1.1 stars", Amount.new(104, :RATED).ui(direction: :ceil)
  end

  def test_hash_display_unit_symbol_singular
    register_plural_kilo

    assert_equal "1 kilo", Amount.new(1, :MASS).ui(unit: :kilo)
  end

  def test_hash_display_unit_symbol_plural
    register_plural_kilo

    assert_equal "3 kilos", Amount.new(3, :MASS).ui(unit: :kilo)
  end

  def test_hash_display_unit_symbol_unit_label_with_count
    register_plural_kilo

    assert_equal "kilo", Amount.new(3, :MASS).unit_label(unit: :kilo, count: 1)
  end

  def test_hash_display_unit_symbol_unit_label_defaults_to_other
    register_plural_kilo

    assert_equal "kilos", Amount.new(1, :MASS).unit_label(unit: :kilo, locale: :en)
  end

  def test_i18n_plural_labels_singular
    register_i18n_plural_searches

    assert_equal "1 search", Amount.new(1, :SEARCHES).ui(locale: :en)
  end

  def test_i18n_plural_labels_zero_is_plural
    register_i18n_plural_searches

    assert_equal "0 searches", Amount.new(0, :SEARCHES).ui(locale: :en)
  end

  def test_i18n_plural_labels_plural
    register_i18n_plural_searches

    assert_equal "2 searches", Amount.new(2, :SEARCHES).ui(locale: :en)
  end

  def test_i18n_plural_labels_unit_label_with_count
    register_i18n_plural_searches

    assert_equal "search", Amount.new(2, :SEARCHES).unit_label(locale: :en, count: 1)
  end

  def test_i18n_plural_labels_unit_label_defaults_to_other
    register_i18n_plural_searches

    assert_equal "searches", Amount.new(1, :SEARCHES).unit_label(locale: :en)
  end

  def test_i18n_plural_labels_unused_when_not_localizing
    register_i18n_plural_searches

    assert_equal "1 SEARCHES", Amount.new(1, :SEARCHES).ui
  end

  def test_i18n_plural_hash_default_singular_uses_locale_rules
    register_plural_searches

    assert_equal "1 search", Amount.new(1, :SEARCHES).ui(locale: :en)
  end

  def test_i18n_plural_hash_default_plural_uses_locale_rules
    register_plural_searches

    assert_equal "2 searches", Amount.new(2, :SEARCHES).ui(locale: :en)
  end

  {
    1 => "1 hledani",
    3 => "3 hledani-few",
    5 => "5 hledani-other"
  }.each do |count, expected|
    define_method("test_i18n_plural_with_few_form_for_#{count}") do
      store_few_form_plural_rule

      assert_equal expected, Amount.new(count, :SEARCHES).ui(locale: :xx)
    end
  end

  def test_missing_plural_form_falls_back_to_other
    I18n.backend.class.include(I18n::Backend::Pluralization)
    I18n.backend.store_translations(:xx, i18n: { plural: { rule: ->(n) { n == 3 ? :few : :other } } },
      amounts: { units: { searches: { other: "o" } } })
    Amount.register :SEARCHES, decimals: 0

    assert_equal "3 o", Amount.new(3, :SEARCHES).ui(locale: :xx)
  end

  # Invalid labels and errors

  def test_hash_display_symbol_without_other_is_rejected
    assert_raises(Amount::Registry::InvalidDisplaySymbol) do
      Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search" }
    end
  end

  def test_hash_display_symbol_without_other_names_other_in_the_message
    error = error_from(Amount::Registry::InvalidDisplaySymbol) do
      Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search" }
    end

    assert_match(/:other/, error.message)
  end

  def test_hash_display_symbol_with_string_keys_is_rejected
    assert_raises(Amount::Registry::InvalidDisplaySymbol) do
      Amount.register :SEARCHES, decimals: 0, display_symbol: { "other" => "x" }
    end
  end

  def test_hash_display_unit_symbol_without_other_is_rejected
    assert_raises(Amount::Registry::InvalidDisplayUnit) do
      Amount.register :MASS, decimals: 0, display_units: { kilo: { scale: 1, symbol: { one: "kilo" } } }
    end
  end

  def test_hash_display_unit_symbol_without_other_names_other_in_the_message
    error = error_from(Amount::Registry::InvalidDisplayUnit) do
      Amount.register :MASS, decimals: 0, display_units: { kilo: { scale: 1, symbol: { one: "kilo" } } }
    end

    assert_match(/:other/, error.message)
  end

  def test_rejected_hash_labels_leave_the_type_unregistered
    error_from(Amount::Registry::InvalidDisplaySymbol) do
      Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search" }
    end
    error_from(Amount::Registry::InvalidDisplaySymbol) do
      Amount.register :SEARCHES, decimals: 0, display_symbol: { "other" => "x" }
    end

    refute Amount.registry.registered?(:SEARCHES)
  end

  def test_unit_label_for_an_unknown_display_unit_raises
    assert_raises(Amount::Registry::InvalidDisplayUnit) { Amount.of_gold("1").unit_label(unit: :nope) }
  end

  def test_unit_label_with_a_locale_without_i18n_raises
    without_i18n do
      assert_raises(ArgumentError) { Amount.of_usd("1").unit_label(locale: :de) }
    end
  end

  def test_locale_without_i18n_raises
    without_i18n do
      assert_raises(ArgumentError) { Amount.of_usd("1").ui(locale: :de) }
    end
  end

  def test_locale_without_i18n_names_i18n_in_the_message
    without_i18n do
      assert_match(/i18n/, error_from(ArgumentError) { Amount.of_usd("1").ui(locale: :de) }.message)
    end
  end

  private

  def localize_in_german
    Amount.localize = true
    I18n.locale = :de
  end

  def register_label_fallback_types
    Amount.register :SEARCHES, decimals: 0, display_symbol: "searches-sym"
    Amount.register :CREDITS, decimals: 0, display_symbol: "cr", label_key: :'custom.credits'
  end

  def store_conventional_unit_labels
    I18n.backend.store_translations(:en, amounts: { units: { searches: "searches", credits: "conv" } })
  end

  def register_searches_in_en_and_de
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:en, amounts: { units: { searches: "searches" } })
    I18n.backend.store_translations(:de, amounts: { units: { searches: "Suchen" } })
  end

  def register_translated_searches
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:en, amounts: { units: { searches: "translated" } })
  end

  def register_german_searches_and_localize
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:de, amounts: { units: { searches: "Suchen" } })
    localize_in_german
  end

  def store_german_gram_label
    I18n.backend.store_translations(:de, amounts: { display_units: { gold: { gram: "Gramm" } } })
  end

  def register_mass_with_label_key
    Amount.register :MASS, decimals: 2, display_symbol: "mass", display_units: {
      kilo: { scale: 1, label_key: "my.kilo" },
      plain: { scale: 1 }
    }
  end

  def register_plural_searches(decimals: 0)
    Amount.register :SEARCHES, decimals:, display_symbol: { one: "search", other: "searches" }
  end

  def register_rated
    Amount.register :RATED, decimals: 2, ui_decimals: 1, display_symbol: { one: "star", other: "stars" }
  end

  def register_plural_kilo
    Amount.register :MASS, decimals: 0, display_units: {
      kilo: { scale: 1, symbol: { one: "kilo", other: "kilos" }, ui_decimals: 0 }
    }
  end

  def register_i18n_plural_searches
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:en, amounts: { units: { searches: { one: "search", other: "searches" } } })
  end

  def store_few_form_plural_rule
    I18n.backend.class.include(I18n::Backend::Pluralization)
    I18n.backend.store_translations(:xx, i18n: { plural: { rule: lambda { |n|
      case n
      when 1 then :one
      when 2..4 then :few
      else :other
      end
    } } })
    I18n.backend.store_translations(:xx, number: { format: { separator: ".", delimiter: "," } },
      amounts: { units: { searches: { one: "hledani", few: "hledani-few", other: "hledani-other" } } })
    Amount.register :SEARCHES, decimals: 0
  end
end
