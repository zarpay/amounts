# frozen_string_literal: true

require "i18n"
require_relative "../test_helper"

class AmountUiParserTest < Minitest::Test
  NBSP = "\u00A0"
  NARROW_NBSP = "\u202F"

  CHAR_NAMES = {
    "," => "comma", "." => "dot", "-" => "minus", "+" => "plus", " " => "space", NBSP => "nbsp",
    NARROW_NBSP => "nnbsp", "\n" => "newline", "$" => "dollar", "€" => "euro"
  }.freeze

  # A method-name-safe spelling of an input, so "1,50,0" and "1.50.0" stay distinct.
  def self.slug(input)
    return "nil" if input.nil?
    return "empty" if input.empty?

    input.each_char.map { |c| c.match?(/[a-zA-Z0-9]/) ? c : "_#{CHAR_NAMES.fetch(c) { format('u%04x', c.ord) }}_" }
         .join.squeeze("_").delete_prefix("_").delete_suffix("_")
  end

  def self.case_name(group, verb, input, symbol, opts)
    "test_#{group}_#{verb}_#{slug(input)}_#{symbol.downcase}_#{opts.fetch(:locale, :plain)}"
  end

  # Defines a test that parses `input` and checks its atomic value. `before`
  # names a private arrange method to run first.
  def self.accepts(group, atomic, input, symbol = :USD, before: nil, **opts)
    define_method(unique_name(case_name(group, :parses, input, symbol, opts))) do
      send(before) if before

      assert_equal atomic, parse(input, symbol, **opts).atomic
    end
  end

  # Defines a test that `input` is rejected with Amount::InvalidInput.
  def self.rejects(group, input, symbol = :USD, before: nil, **opts)
    define_method(unique_name(case_name(group, :rejects, input, symbol, opts))) do
      send(before) if before

      assert_raises(Amount::InvalidInput, "#{input.inspect} should be rejected") { parse(input, symbol, **opts) }
    end
  end

  # A later define_method with the same name would silently replace a case.
  def self.unique_name(name)
    raise ArgumentError, "duplicate test name #{name}" if method_defined?(name)

    name
  end

  def setup
    AmountTestSupport.register_default_types!
    @previous_locale = I18n.locale
    @previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = %i[en de fr]
    I18n.backend.store_translations(:en, number: { format: { delimiter: ",", separator: "." } })
    I18n.backend.store_translations(:de, number: { format: { delimiter: ".", separator: "," } })
    I18n.backend.store_translations(:fr, number: { format: { delimiter: " ", separator: "," } })
    Amount.localize = false
  end

  def teardown
    Amount.localize = false
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    Amount.registry.clear!
  end

  # Issue examples

  def test_issue_example_de_equals_new
    assert_equal Amount.new("1500.50", :USD), parse("1.500,50", locale: :de)
  end

  def test_issue_example_en_equals_new
    assert_equal Amount.new("1500.50", :USD), parse("1,500.50", locale: :en)
  end

  def test_issue_example_plain_equals_new
    assert_equal Amount.new("1500.50", :USD), parse("1500.50")
  end

  def test_issue_example_de_atomic
    assert_equal 150_050, parse("1.500,50", locale: :de).atomic
  end

  # Without a locale there are no delimiters

  accepts :plain, 150_000, "1500"
  rejects :plain, "1,500.50"
  rejects :plain, "1.500,50"

  def test_localize_uses_i18n_locale
    Amount.localize = true
    I18n.locale = :de

    assert_equal 150_050, parse("1.500,50").atomic
  end

  def test_explicit_locale_overrides_localize
    Amount.localize = true
    I18n.locale = :de

    assert_equal 150_050, parse("1,500.50", locale: :en).atomic
  end

  # Whitespace, including NBSP

  accepts :whitespace, 150_050, " #{NBSP}1.500,50#{NBSP}\n", locale: :de
  accepts :whitespace, 150_050, "  1,500.50 ", locale: :en
  accepts :whitespace, 150_050, "#{NBSP}1500.50#{NARROW_NBSP}"
  accepts :whitespace, 150_050, "1 500,50", locale: :fr
  accepts :whitespace, 150_050, "1#{NBSP}500,50", locale: :fr

  # Signs

  accepts :signs, -150_050, "-1.500,50", locale: :de
  accepts :signs, -150_050, "-1,500.50", locale: :en
  accepts :signs, 150_050, "+1,500.50", locale: :en
  accepts :signs, -150_050, "$-1,500.50", locale: :en
  accepts :signs, -150_050, "-$1,500.50", locale: :en
  rejects :signs, "--1.50"
  rejects :signs, "+-1.50"
  rejects :signs, "1.50-"

  # Delimiter groups

  accepts :delimiter_groups, 123_456_789_00, "123,456,789.00", locale: :en
  accepts :delimiter_groups, 123_456_789_00, "123.456.789,00", locale: :de
  accepts :delimiter_groups, 150_000, "1500", locale: :en
  accepts :delimiter_groups, 150_000, "1500", locale: :de
  %w[1,50,0 1,5000 12,34,567 ,500 1,,500 1,500,5].each { |bad| rejects :delimiter_groups, bad, locale: :en }
  %w[1.50.0 1.5000 12.34.567 .500 1..500].each { |bad| rejects :delimiter_groups, bad, locale: :de }

  # Decimal places

  accepts :decimal_places, 150_000, "1.500,00", locale: :de
  accepts :decimal_places, 150_050, "1.500,50", locale: :de
  accepts :decimal_places, 150_000, "1,500", :USD, locale: :en
  rejects :decimal_places, "1,500.505", locale: :en
  rejects :decimal_places, "1.500,505", locale: :de
  rejects :decimal_places, "0.001"

  # Separator used twice

  rejects :separator_twice, "1.500.50", locale: :en
  rejects :separator_twice, "1,500,50", locale: :de
  rejects :separator_twice, "1.50.50"

  # Malformed numbers

  ["", "   ", NBSP, "abc", "$", "1.", ".5", "1e3", "1,500.", "- ", "1 2"].each do |bad|
    rejects :malformed, bad, locale: :en
  end
  rejects :malformed, nil

  # Labels at either end

  accepts :labels, 150_050, "$1,500.50", locale: :en
  accepts :labels, 150_050, "$ 1,500.50", locale: :en
  accepts :labels, 150_050, "1.500,50 $", locale: :de
  accepts :labels, 150_050, "1.500,50$", locale: :de
  accepts :labels, 2_500_000_000, "2.5 SOL", :SOL
  accepts :labels, 1_500, "1.500 logs", :LOGS, locale: :de
  accepts :labels, 1_500, "logs 1,500", :LOGS, locale: :en

  accepts :euro_label, 150_050, "1.500,50 €", :EUR, before: :register_euro, locale: :de
  accepts :euro_label, 150_050, "€1,500.50", :EUR, before: :register_euro, locale: :en

  # Another type's label

  rejects :other_types_label, "1,500.50 SOL", :USD, locale: :en
  rejects :other_types_label, "$1.500,50", :SOL, locale: :de
  rejects :other_types_label, "1.500 logs", :USD, locale: :de
  rejects :other_types_label, "$1,500.50 $", :USD, locale: :en

  # Plural and translated labels

  accepts :plural_label, 1, "1 search", :SEARCHES, before: :register_plural_searches
  accepts :plural_label, 1500, "1,500 searches", :SEARCHES, before: :register_plural_searches, locale: :en
  accepts :plural_label, 1500, "1.500 searches", :SEARCHES, before: :register_plural_searches, locale: :de
  rejects :plural_label, "1 logs", :SEARCHES, before: :register_plural_searches

  accepts :translated_label, 1500, "1.500 Suchen", :SEARCHES, before: :translate_searches, locale: :de
  accepts :translated_label, 1, "1 Suche", :SEARCHES, before: :translate_searches, locale: :de
  accepts :translated_label, 1, "1 s", :SEARCHES, before: :translate_searches, locale: :de
  rejects :translated_label, "1 Suchen", :SEARCHES, before: :translate_searches, locale: :en

  # Zero decimals

  accepts :decimals_zero, 1_500_000, "1.500.000", :LOGS, locale: :de
  accepts :decimals_zero, 1_500_000, "1,500,000", :LOGS, locale: :en
  accepts :decimals_zero, -1500, "-1,500", :LOGS, locale: :en
  accepts :decimals_zero, 0, "0", :LOGS
  rejects :decimals_zero, "1,5", :LOGS, locale: :en
  rejects :decimals_zero, "1.500,5", :LOGS, locale: :de
  rejects :decimals_zero, "1.500,0", :LOGS, locale: :de
  rejects :decimals_zero, "1500.5", :LOGS

  # High precision

  accepts :high_precision, 1_234_567_891, "1.234567891", :SOL
  accepts :high_precision, 123_456_789_123_456_789_012_345_678, "123456789123456789.012345678", :SOL

  # Without the i18n gem

  def test_explicit_locale_without_i18n_raises
    without_i18n { assert_raises(ArgumentError) { parse("1.50", locale: :de) } }
  end

  def test_plain_parsing_works_without_i18n
    without_i18n { assert_equal 150, parse("1.50").atomic }
  end

  # Round trips of `ui` output

  UI_USD_VALUES = %w[0 0.01 0.99 1 9.99 12.34 123.45 999.99 1000 1000.01 12345.67 123456.78 1234567.89
                     -0.01 -1 -999.99 -1000 -1234567.89 99999999999.99].freeze
  UI_LOGS_COUNTS = [0, 7, 999, 1000, 1_234_567, -1_500].freeze

  %i[en de fr].each do |locale|
    define_method("test_round_trips_usd_ui_#{locale}") do
      amounts = UI_USD_VALUES.map { |value| Amount.of_usd(value) }

      assert_equal amounts, amounts.map { |amount| parse(amount.ui(locale:), locale:) }
    end

    define_method("test_round_trips_usd_undecorated_ui_#{locale}") do
      amounts = UI_USD_VALUES.map { |value| Amount.of_usd(value) }

      assert_equal amounts, amounts.map { |amount| parse(amount.ui(locale:, decorated: false), locale:) }
    end

    define_method("test_round_trips_logs_ui_#{locale}") do
      amounts = UI_LOGS_COUNTS.map { |n| Amount.of_logs(n) }

      assert_equal amounts, amounts.map { |amount| parse(amount.ui(locale:), :LOGS, locale:) }
    end
  end

  # (n**3) + n cents for n in 0, 7, 14, ..., 3997, in each locale and sign
  RANGE_CENTS = (0..4000).step(7).map { |n| (n**3) + n }.freeze

  %i[en de].each do |locale|
    { "positive" => 1, "negative" => -1 }.each do |sign, factor|
      define_method("test_round_trips_over_a_range_#{sign}_#{locale}") do
        amounts = RANGE_CENTS.map { |cents| Amount.new(cents * factor, :USD) }

        assert_equal amounts, amounts.map { |amount| parse(amount.ui(locale:), locale:) }
      end
    end
  end

  private

  def parse(input, symbol = :USD, **opts)
    Amount.parse_ui(input, symbol, **opts)
  end

  def register_euro
    Amount.register :EUR, decimals: 2, display_symbol: "€"
  end

  def register_plural_searches
    Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search", other: "searches" }
  end

  def translate_searches
    Amount.register :SEARCHES, decimals: 0, display_symbol: "s"
    I18n.backend.store_translations(:de, amounts: { units: { searches: { one: "Suche", other: "Suchen" } } })
  end

  # Runs the block as if the i18n gem were not loaded.
  def without_i18n
    i18n = Object.send(:remove_const, :I18n)
    yield
  ensure
    Object.const_set(:I18n, i18n)
  end
end
