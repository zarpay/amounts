# frozen_string_literal: true

require "i18n"
require_relative "../test_helper"
require_relative "../support/locale_test_setup"

class AmountCompactTest < Minitest::Test
  include LocaleTestSetup

  def setup
    super
    Amount.register :TOKENS, decimals: 0
  end

  # Off by default

  def test_without_compact_output_is_unchanged
    assert_equal "50000000 TOKENS", tokens(50_000_000).ui
  end

  def test_compact_false_output_is_unchanged
    assert_equal "50000000 TOKENS", tokens(50_000_000).ui(compact: false)
  end

  def test_without_compact_prefix_type_output_is_unchanged
    assert_equal "$1500000.00", Amount.of_usd("1500000").ui
  end

  # Thresholds

  def test_below_one_thousand_is_formatted_normally
    assert_equal "999 TOKENS", tokens(999).ui(compact: true)
  end

  def test_below_one_thousand_keeps_decimals
    assert_equal "$999.99", Amount.of_usd("999.99").ui(compact: true)
  end

  def test_zero_is_formatted_normally
    assert_equal "0 TOKENS", tokens(0).ui(compact: true)
  end

  # Each row: count => expected compact output (default floor rounding).
  {
    1_000 => "1K TOKENS",
    999_999 => "999K TOKENS",
    1_000_000 => "1M TOKENS",
    999_999_999 => "999M TOKENS",
    1_000_000_000 => "1B TOKENS",
    1_000_000_000_000 => "1T TOKENS"
  }.each do |count, expected|
    define_method("test_scale_threshold_#{count}") do
      assert_equal expected, tokens(count).ui(compact: true)
    end
  end

  {
    1_500_000_000_000_000 => "1.5Qa TOKENS",
    10**18 => "1Qi TOKENS",
    10**21 => "1Sx TOKENS",
    10**24 => "1Sp TOKENS",
    10**27 => "1Oc TOKENS",
    10**30 => "1No TOKENS",
    10**33 => "1Dc TOKENS",
    (10**21) - 1 => "999Qi TOKENS"
  }.each do |count, expected|
    define_method("test_scales_past_trillions_#{count}") do
      assert_equal expected, tokens(count).ui(compact: true)
    end
  end

  def test_scales_past_trillions_ceil_rounds_into_sextillions
    assert_equal "1Sx TOKENS", tokens((10**21) - 1).ui(compact: true, direction: :ceil)
  end

  def test_beyond_decillions_stays_in_decillions
    assert_equal "1500Dc TOKENS", tokens(15 * (10**35)).ui(compact: true)
  end

  def test_beyond_decillions_stays_in_decillions_with_locale_delimiter
    assert_equal "1.500Dc TOKENS", tokens(15 * (10**35)).ui(compact: true, locale: :de)
  end

  # Precision and rounding

  {
    1_234 => "1.23K TOKENS",
    12_345_678 => "12.3M TOKENS",
    123_456_789_012 => "123B TOKENS"
  }.each do |count, expected|
    define_method("test_three_significant_digits_by_default_#{count}") do
      assert_equal expected, tokens(count).ui(compact: true)
    end
  end

  {
    50_000_000 => "50M TOKENS",
    1_500 => "1.5K TOKENS",
    1_010 => "1.01K TOKENS"
  }.each do |count, expected|
    define_method("test_trailing_zeros_are_trimmed_#{count}") do
      assert_equal expected, tokens(count).ui(compact: true)
    end
  end

  def test_floor_never_rounds_up
    assert_equal "1.99M TOKENS", tokens(1_999_999).ui(compact: true)
  end

  def test_ceil_rounds_up_to_whole
    assert_equal "2M TOKENS", tokens(1_999_999).ui(compact: true, direction: :ceil)
  end

  def test_ceil_rounds_up_last_significant_digit
    assert_equal "1.24K TOKENS", tokens(1_234).ui(compact: true, direction: :ceil)
  end

  def test_rounding_into_the_next_scale_uses_that_scale_millions
    assert_equal "1M TOKENS", tokens(999_999).ui(compact: true, direction: :ceil)
  end

  def test_rounding_into_the_next_scale_uses_that_scale_trillions
    assert_equal "1T TOKENS", tokens(999_999_999_999).ui(compact: true, direction: :ceil)
  end

  # floor goes toward negative infinity, as `ui` does for any negative amount

  def test_negative_exact_value
    assert_equal "-1.5M TOKENS", tokens(-1_500_000).ui(compact: true)
  end

  def test_negative_floor_rounds_away_from_zero
    assert_equal "-2M TOKENS", tokens(-1_999_999).ui(compact: true)
  end

  def test_negative_ceil_rounds_toward_zero
    assert_equal "-1.99M TOKENS", tokens(-1_999_999).ui(compact: true, direction: :ceil)
  end

  def test_negative_floor_rounds_into_the_next_scale
    assert_equal "-1M TOKENS", tokens(-999_999).ui(compact: true)
  end

  def test_negative_below_one_thousand_is_formatted_normally
    assert_equal "-999 TOKENS", tokens(-999).ui(compact: true)
  end

  def test_negative_prefix_type
    assert_equal "$-1.5K", Amount.of_usd("-1500").ui(compact: true)
  end

  def test_precision_two_floors
    assert_equal "1.2M TOKENS", tokens(1_299_999).ui(compact: { precision: 2 })
  end

  def test_precision_one
    assert_equal "1M TOKENS", tokens(1_299_999).ui(compact: { precision: 1 })
  end

  def test_precision_two_trims_trailing_zero
    assert_equal "150K TOKENS", tokens(155_000).ui(compact: { precision: 2 })
  end

  def test_precision_five
    assert_equal "1.2345M TOKENS", tokens(1_234_567).ui(compact: { precision: 5 })
  end

  def test_empty_options_hash_uses_default_precision
    assert_equal "1.23M TOKENS", tokens(1_234_567).ui(compact: {})
  end

  {
    "symbol" => :yes,
    "zero_precision" => { precision: 0 },
    "string_precision" => { precision: "2" },
    "unknown_key" => { digits: 2 }
  }.each do |name, compact|
    define_method("test_invalid_compact_option_raises_#{name}") do
      assert_raises(ArgumentError) { tokens(1).ui(compact:) }
    end
  end

  def test_compact_ignores_fractional_atomic_noise
    assert_equal "$1.23M", Amount.of_usdc("1234567.891234").ui(compact: true)
  end

  # Labels and templates

  def test_prefix_type_wraps_the_compacted_number
    assert_equal "$1.5M", Amount.of_usd("1500000").ui(compact: true)
  end

  def test_suffix_type_wraps_the_compacted_number
    assert_equal "2.5K SOL", Amount.of_sol("2500").ui(compact: true)
  end

  def test_display_format_wraps_the_compacted_number
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%n %u"

    assert_equal "1.5M €", Amount.of_eur("1500000").ui(compact: true)
  end

  def test_undecorated_returns_just_the_compacted_number
    assert_equal "50M", tokens(50_000_000).ui(compact: true, decorated: false)
  end

  def test_undecorated_keeps_the_locale_scale_word
    german_keys

    assert_equal "1,5 Mio.", tokens(1_500_000).ui(compact: true, decorated: false, locale: :de)
  end

  def test_plural_label_agrees_with_the_full_value
    register_searches

    assert_equal "1K searches", Amount.of_searches(1_000).ui(compact: true)
  end

  def test_singular_label_below_one_thousand
    register_searches

    assert_equal "1 search", Amount.of_searches(1).ui(compact: true)
  end

  def test_display_unit_compacts_the_scaled_number
    assert_equal "31.1K g", Amount.of_gold("1000").ui(unit: :gram, compact: true)
  end

  def test_display_unit_compacts_the_scaled_number_with_ceil
    assert_equal "31.2K g", Amount.of_gold("1000").ui(unit: :gram, compact: true, direction: :ceil)
  end

  def test_display_unit_compacts_another_unit
    assert_equal "1K oz t", Amount.of_gold("1000").ui(unit: :oz_t, compact: true)
  end

  def test_display_unit_below_one_thousand_uses_its_decimals
    assert_equal "311.03 g", Amount.of_gold("10").ui(unit: :gram, compact: true)
  end

  def test_wire_format_ignores_compact
    assert_equal "TOKENS|50000000", tokens(50_000_000).to_s
  end

  # Scale words

  def test_short_forms_when_not_localizing_even_with_locale_keys
    german_keys

    assert_equal "1.5M TOKENS", tokens(1_500_000).ui(compact: true)
  end

  def test_en_with_rails_keys_million
    english_keys

    assert_equal "50 Million TOKENS", tokens(50_000_000).ui(compact: true, locale: :en)
  end

  def test_en_with_rails_keys_thousand
    english_keys

    assert_equal "1.23 Thousand TOKENS", tokens(1_234).ui(compact: true, locale: :en)
  end

  def test_en_with_rails_keys_billion_prefix_type
    english_keys

    assert_equal "$1.5 Billion", Amount.of_usd("1500000000").ui(compact: true, locale: :en)
  end

  def test_en_with_rails_keys_quadrillion
    english_keys

    assert_equal "1.5 Quadrillion TOKENS", tokens(1_500_000_000_000_000).ui(compact: true, locale: :en)
  end

  # no `quintillion` key: falls back to the short form
  def test_en_with_rails_keys_missing_quintillion_falls_back_to_short_form
    english_keys

    assert_equal "2Qi TOKENS", tokens(2 * (10**18)).ui(compact: true, locale: :en)
  end

  {
    1_500_000 => "1,5 Mio. Token",
    1_999_999 => "1,99 Mio. Token",
    12_000 => "12 Tsd. Token",
    999 => "999 Token"
  }.each do |count, expected|
    define_method("test_de_with_its_own_keys_#{count}") do
      german_keys

      assert_equal expected, tokens(count).ui(compact: true, locale: :de)
    end
  end

  def test_localize_true_uses_i18n_locale
    german_keys
    Amount.localize = true
    I18n.locale = :de

    assert_equal "1,5 Mio. Token", tokens(1_500_000).ui(compact: true)
  end

  def test_pluralized_scale_word_one
    store_decimal_units(:de, units: { million: { one: "Million", other: "Millionen" } })

    assert_equal "1 Million TOKENS", tokens(1_000_000).ui(compact: true, locale: :de)
  end

  def test_pluralized_scale_word_other
    store_decimal_units(:de, units: { million: { one: "Million", other: "Millionen" } })

    assert_equal "2,5 Millionen TOKENS", tokens(2_500_000).ui(compact: true, locale: :de)
  end

  def test_locale_format_joins_number_and_word
    store_decimal_units(:de, format: "%n%u", units: { thousand: "k" })

    assert_equal "1,5k TOKENS", tokens(1_500).ui(compact: true, locale: :de)
  end

  def test_missing_locale_keys_fall_back_to_short_form
    assert_equal "1,5M TOKENS", tokens(1_500_000).ui(compact: true, locale: :de)
  end

  def test_missing_locale_word_falls_back_to_short_form
    german_keys

    assert_equal "1,5B Token", tokens(1_500_000_000).ui(compact: true, locale: :de)
  end

  def test_locale_format_without_number_is_ignored
    store_decimal_units(:de, format: "%u", units: { thousand: "Tsd." })

    assert_equal "1,5 Tsd. TOKENS", tokens(1_500).ui(compact: true, locale: :de)
  end

  def test_compact_works_without_i18n
    without_i18n { assert_equal "50M TOKENS", tokens(50_000_000).ui(compact: true) }
  end

  private

  def tokens(count)
    Amount.of_tokens(count)
  end

  def register_searches
    Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search", other: "searches" }
  end

  # number.human.decimal_units, the keys Rails' number_to_human reads
  def store_decimal_units(locale, units:, format: nil)
    decimal_units = { units: }
    decimal_units[:format] = format if format
    I18n.backend.store_translations(locale, number: { human: { decimal_units: } })
  end

  def english_keys
    store_decimal_units(:en, format: "%n %u", units: {
                          unit: "", thousand: "Thousand", million: "Million", billion: "Billion", trillion: "Trillion",
                          quadrillion: "Quadrillion"
                        })
  end

  def german_keys
    store_decimal_units(:de, format: "%n %u", units: { thousand: "Tsd.", million: "Mio." })
    I18n.backend.store_translations(:de, amounts: { units: { tokens: "Token" } })
  end
end
