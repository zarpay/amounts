# frozen_string_literal: true

require_relative "../../test_helper"

class AmountCoercionTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_coerce_decimal_returns_big_decimal_unchanged
    value = BigDecimal("1.25")

    assert_same value, Amount.coerce_decimal(value)
  end

  def test_coerce_decimal_converts_integer
    assert_equal BigDecimal("3"), Amount.coerce_decimal(3)
  end

  def test_coerce_decimal_converts_string
    assert_equal BigDecimal("1.25"), Amount.coerce_decimal("1.25")
  end

  def test_coerce_decimal_converts_rational
    assert_equal BigDecimal("1.5"), Amount.coerce_decimal(Rational(3, 2))
  end

  def test_coerce_decimal_converts_float_through_its_string_form
    assert_equal BigDecimal("0.1"), Amount.coerce_decimal(0.1)
  end

  def test_cross_type_addition_without_rate_names_both_types
    error = error_from(Amount::TypeMismatch) { Amount.of_usdc("1") + Amount.of_sol("1") }

    assert_equal "type mismatch: USDC vs SOL", error.message
  end

  def test_adding_a_non_amount_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Amount.of_usdc("1") + 1 }
  end

  def test_adding_a_non_amount_names_its_class
    assert_match(/vs Integer\z/, error_from(Amount::TypeMismatch) { Amount.of_usdc("1") + 1 }.message)
  end
end
