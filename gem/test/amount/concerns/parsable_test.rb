# frozen_string_literal: true

require "i18n"
require_relative "../../test_helper"

class AmountParsableTest < Minitest::Test
  class GoldAmount < Amount
    def purity = "24k"
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

  def test_parse_reads_atomic_value
    assert_equal 1_500_000, Amount.parse("USDC|1.5").atomic
  end

  def test_parse_roundtrips_to_s
    assert_equal "USDC|1.50", Amount.parse("USDC|1.5").to_s
  end

  def test_wire_parse_unchanged
    assert_equal 150_050, Amount.parse("USD|1500.50").atomic
  end

  def test_parse_dispatches_to_registered_subclass
    use_gold_amount_registry!

    assert_instance_of GoldAmount, Amount.parse("GOLD|1.0")
  end

  def test_parse_ui_returns_amount_for_registered_class
    assert_instance_of Amount, Amount.parse_ui("1.50", :USD)
  end

  def test_parse_ui_unregistered_symbol_raises_unknown_type_from_new
    assert_raises(Amount::Registry::UnknownType) { Amount.new("1", :NOPE) }
  end

  def test_parse_ui_unregistered_symbol_raises_unknown_type
    assert_raises(Amount::Registry::UnknownType) { Amount.parse_ui("1", :NOPE) }
  end

  def test_parse_ui_unregistered_symbol_message_matches_new
    new_error = error_from(Amount::Registry::UnknownType) { Amount.new("1", :NOPE) }
    error = error_from(Amount::Registry::UnknownType) { Amount.parse_ui("1", :NOPE) }

    assert_equal new_error.message, error.message
  end

  def test_parse_ui_returns_registered_subclass
    use_gold_amount_registry!

    assert_instance_of GoldAmount, Amount.parse_ui("1.500,5 oz", :GOLD, locale: :de)
  end

  def test_parse_ui_into_registered_subclass_reads_atomic_value
    use_gold_amount_registry!

    assert_equal 15_005_000, Amount.parse_ui("1.500,5 oz", :GOLD, locale: :de).atomic
  end

  def test_parse_ui_into_registered_subclass_has_subclass_behavior
    use_gold_amount_registry!

    assert_equal "24k", Amount.parse_ui("1.500,5 oz", :GOLD, locale: :de).purity
  end

  def test_parse_ui_into_registered_subclass_rejects_too_many_decimals
    use_gold_amount_registry!

    assert_raises(Amount::InvalidInput) { Amount.parse_ui("1,00001", :GOLD, locale: :de) }
  end

  private

  # Replaces the default types with GOLD registered to {GoldAmount}.
  def use_gold_amount_registry!
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 4, display_symbol: "oz", class: GoldAmount
  end
end
