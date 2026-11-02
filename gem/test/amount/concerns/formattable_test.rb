# frozen_string_literal: true

require "i18n"
require_relative "../../test_helper"
require_relative "../../support/locale_test_setup"

class AmountFormattableTest < Minitest::Test
  include LocaleTestSetup

  NBSP = " "

  # Template primitives

  def test_fill_places_number_before_label
    assert_equal "12.50 €", Amount::Formattable.fill("%n %u", number: "12.50", label: "€")
  end

  def test_fill_places_label_before_number
    assert_equal "€12.50", Amount::Formattable.fill("%u%n", number: "12.50", label: "€")
  end

  def test_fill_does_not_expand_placeholders_inside_the_values
    assert_equal "5 %n", Amount::Formattable.fill("%n %u", number: "5", label: "%n")
  end

  {
    prefix: "%u%n",
    suffix: "%n %u",
    nil => "%n %u"
  }.each do |position, template|
    define_method("test_template_for_#{position.inspect.delete(':')}_matches_the_legacy_layout") do
      assert_equal template, Amount::Formattable.template_for(position)
    end
  end

  def test_valid_template_accepts_a_string_with_the_number
    assert Amount::Formattable.valid_template?("%n")
  end

  {
    "string_without_the_number" => "%u",
    "symbol" => :'%n',
    "nil" => nil
  }.each do |name, template|
    define_method("test_valid_template_rejects_a_#{name}") do
      refute Amount::Formattable.valid_template?(template)
    end
  end

  # Amount#display_format

  def test_display_format_is_part_of_the_amount_api
    assert_includes Amount.ancestors, Amount::Formattable
  end

  def test_display_format_is_part_of_an_amount_subclass_api
    assert_includes Class.new(Amount).ancestors, Amount::Formattable
  end

  def test_display_format_returns_the_registered_prefix_template
    assert_equal "%u%n", Amount.of_usd("1").display_format
  end

  def test_display_format_returns_the_registered_suffix_template
    assert_equal "%n %u", Amount.of_sol("1").display_format
  end

  def test_display_format_for_a_display_unit_with_a_format
    register_mass

    assert_equal "%n#{NBSP}%u", Amount.new("1", :MASS).display_format(unit: :kilo)
  end

  def test_display_format_for_a_display_unit_with_a_position
    register_mass

    assert_equal "%u%n", Amount.new("1", :MASS).display_format(unit: :pre)
  end

  def test_display_format_for_a_display_unit_named_by_a_string_without_a_template
    register_mass

    assert_equal "[%u] %n", Amount.new("1", :MASS).display_format(unit: "plain")
  end

  def test_display_format_for_a_locale_without_a_template
    register_eur_with_german_template

    assert_equal "%u%n", Amount.of_eur("1").display_format(locale: :en)
  end

  def test_display_format_for_a_locale_with_a_template
    register_eur_with_german_template

    assert_equal "%n#{NBSP}%u", Amount.of_eur("1").display_format(locale: :de)
  end

  def test_display_format_without_a_locale_ignores_locale_templates
    register_eur_with_german_template

    assert_equal "%u%n", Amount.of_eur("1").display_format
  end

  def test_display_format_for_an_unknown_display_unit_raises
    register_mass

    assert_raises(Amount::Registry::InvalidDisplayUnit) { Amount.new("1", :MASS).display_format(unit: :ton) }
  end

  def test_display_format_for_a_display_unit_of_a_type_without_units_raises
    assert_raises(Amount::Registry::InvalidDisplayUnit) { Amount.of_usd("1").display_format(unit: :cents) }
  end

  def test_display_format_with_a_locale_requires_i18n
    without_i18n do
      assert_raises(ArgumentError) { Amount.of_usd("1").display_format(locale: :de) }
    end
  end

  # Rendering without templates

  def test_output_without_templates_prefix
    assert_equal "$1.50", Amount.of_usdc("1.5").ui
  end

  def test_output_without_templates_negative_prefix
    assert_equal "$-5.00", Amount.of_usd("-5").ui
  end

  def test_output_without_templates_suffix
    assert_equal "1.5000 oz t", Amount.of_gold("1.5").ui
  end

  def test_output_without_templates_display_unit
    assert_equal "46.65 g", Amount.of_gold("1.5").ui(unit: :gram)
  end

  def test_output_without_templates_in_en
    assert_equal "$1,500.00", Amount.of_usd("1500").ui(locale: :en)
  end

  def test_output_without_templates_in_de
    assert_equal "$1.500,00", Amount.of_usd("1500").ui(locale: :de)
  end

  # Rendering a type's template

  def test_display_format_places_number_and_label
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u %n"

    assert_equal "€ 12.50", Amount.of_eur("12.5").ui
  end

  def test_display_format_keeps_the_sign_in_the_number
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u%n"

    assert_equal "€-12.50", Amount.of_eur("-12.5").ui
  end

  def test_display_format_keeps_non_breaking_spaces
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%n#{NBSP}%u"

    assert_equal "12.50#{NBSP}€", Amount.of_eur("12.5").ui
  end

  def test_display_format_places_a_singular_label
    register_plural_searches_with_template

    assert_equal "search: 1", Amount.of_searches(1).ui
  end

  def test_display_format_places_a_plural_label
    register_plural_searches_with_template

    assert_equal "searches: 3", Amount.of_searches(3).ui
  end

  def test_display_format_works_without_i18n
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%n#{NBSP}%u"

    without_i18n { assert_equal "12.50#{NBSP}€", Amount.of_eur("12.5").ui }
  end

  def test_undecorated_output_is_the_number_alone
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "[%u] %n"

    assert_equal "12.50", Amount.of_eur("12.5").ui(decorated: false)
  end

  def test_empty_label_renders_the_number_alone
    Amount.register :BARE, decimals: 0, display_symbol: "", display_format: "%n %u"

    assert_equal "7", Amount.of_bare(7).ui
  end

  def test_wire_format_ignores_display_format
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u%n"

    assert_equal "EUR|12.50", Amount.of_eur("12.5").to_s
  end

  # Locale templates for a type

  def test_locale_without_a_template_uses_the_types_template
    register_eur_with_german_template

    assert_equal "€1,234.50", Amount.of_eur("1234.5").ui(locale: :en)
  end

  def test_locale_template_replaces_the_types_template
    register_eur_with_german_template

    assert_equal "1.234,50#{NBSP}€", Amount.of_eur("1234.5").ui(locale: :de)
  end

  def test_locale_template_keeps_the_sign_in_the_number
    register_eur_with_german_template

    assert_equal "-1.234,50#{NBSP}€", Amount.of_eur("-1234.5").ui(locale: :de)
  end

  def test_locale_template_is_ignored_when_not_localizing
    register_eur_with_german_template

    assert_equal "€1234.50", Amount.of_eur("1234.5").ui
  end

  def test_locale_template_follows_i18n_locale_when_localize_is_on
    register_eur_with_german_template
    Amount.localize = true
    I18n.locale = :de

    assert_equal "1.234,50#{NBSP}€", Amount.of_eur("1234.5").ui
  end

  def test_locale_template_overrides_display_position
    I18n.backend.store_translations(:de, amounts: { formats: { usd: "%n %u" } })

    assert_equal "1.500,00 $", Amount.of_usd("1500").ui(locale: :de)
  end

  def test_locale_template_uses_the_translated_label
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:de, amounts: { units: { searches: "Suchen" }, formats: { searches: "%u: %n" } })

    assert_equal "Suchen: 1.500", Amount.new(1500, :SEARCHES).ui(locale: :de)
  end

  def test_locale_template_without_number_is_ignored
    register_eur_with_german_template
    I18n.backend.store_translations(:de, amounts: { formats: { eur: "%u" } })

    assert_equal "€1.234,50", Amount.of_eur("1234.5").ui(locale: :de)
  end

  # Display units

  def test_display_unit_format_places_number_and_label
    register_mass

    assert_equal "1.00#{NBSP}kg", Amount.new("1", :MASS).ui(unit: :kilo)
  end

  def test_display_unit_position_still_works
    register_mass

    assert_equal "p1.00", Amount.new("1", :MASS).ui(unit: :pre)
  end

  def test_display_unit_without_template_uses_the_types
    register_mass

    assert_equal "[x] 1.00", Amount.new("1", :MASS).ui(unit: :plain)
  end

  def test_display_unit_locale_template_overrides_its_format
    register_mass_with_german_kilo_template

    assert_equal "kg 1,00", Amount.new("1", :MASS).ui(unit: :kilo, locale: :de)
  end

  def test_display_unit_locale_template_is_only_used_for_its_locale
    register_mass_with_german_kilo_template

    assert_equal "1.00#{NBSP}kg", Amount.new("1", :MASS).ui(unit: :kilo, locale: :en)
  end

  def test_display_unit_without_template_uses_the_types_locale_template
    register_mass_with_german_type_template

    assert_equal "x: 1,00", Amount.new("1", :MASS).ui(unit: :plain, locale: :de)
  end

  def test_display_unit_position_wins_over_the_types_locale_template
    register_mass_with_german_type_template

    assert_equal "p1,00", Amount.new("1", :MASS).ui(unit: :pre, locale: :de)
  end

  def test_display_unit_undecorated_output_is_the_number_alone
    register_mass

    assert_equal "1.00", Amount.new("1", :MASS).ui(unit: :kilo, decorated: false)
  end

  private

  def register_eur_with_german_template
    Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u%n"
    I18n.backend.store_translations(:de, amounts: { formats: { eur: "%n#{NBSP}%u" } })
  end

  def register_mass
    Amount.register :MASS, decimals: 2, display_symbol: "mass", display_format: "[%u] %n", display_units: {
      kilo: { scale: 1, symbol: "kg", format: "%n#{NBSP}%u" },
      pre: { scale: 1, symbol: "p", position: :prefix },
      plain: { scale: 1, symbol: "x" }
    }
  end

  def register_mass_with_german_kilo_template
    register_mass
    I18n.backend.store_translations(:de, amounts: { display_unit_formats: { mass: { kilo: "%u %n" } } })
  end

  def register_mass_with_german_type_template
    register_mass
    I18n.backend.store_translations(:de, amounts: { formats: { mass: "%u: %n" } })
  end

  def register_plural_searches_with_template
    Amount.register :SEARCHES, decimals: 0,
                               display_symbol: { one: "search", other: "searches" },
                               display_format: "%u: %n"
  end
end
