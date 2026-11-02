# frozen_string_literal: true

require "bigdecimal"
require_relative "../../test_helper"

class AmountArithmeticTest < Minitest::Test
  class GoldAmount < Amount
    def purity_estimate
      "24k"
    end
  end

  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_frozen_amount_addition_returns_correct_sum
    assert_equal Amount.new("3", :USDC), frozen_sum
  end

  def test_frozen_amount_addition_returns_unfrozen_result
    refute_predicate frozen_sum, :frozen?
  end

  def test_addition_same_type
    assert_equal Amount.new("2.0", :USDC), Amount.new("1.5", :USDC) + Amount.new("0.5", :USDC)
  end

  def test_addition_cross_type_uses_registered_rate
    Amount.register_default_rate :USD, :USDC, 1

    result = Amount.new("10.00", :USDC) + Amount.new("5.00", :USD)

    assert_equal Amount.new("15.00", :USDC), result
  end

  def test_addition_different_type_raises_without_rate
    assert_raises(Amount::TypeMismatch) do
      Amount.new(1, :USDC) + Amount.new(1, :SOL)
    end
  end

  def test_subtraction_cross_type_uses_registered_rate
    Amount.register_default_rate :USD, :USDC, 1

    result = Amount.new("10.00", :USDC) - Amount.new("5.00", :USD)

    assert_equal Amount.new("5.00", :USDC), result
  end

  def test_subtraction_different_type_raises_without_rate
    assert_raises(Amount::TypeMismatch) do
      Amount.new(1, :USDC) - Amount.new(1, :USD)
    end
  end

  def test_asymmetric_rate_allows_configured_direction
    Amount.register_default_rate :USD, :USDC, 1

    assert_equal Amount.new("15.00", :USDC), Amount.new("10.00", :USDC) + Amount.new("5.00", :USD)
  end

  def test_asymmetric_rate_rejects_reverse_direction
    Amount.register_default_rate :USD, :USDC, 1

    assert_raises(Amount::TypeMismatch) do
      Amount.new("5.00", :USD) + Amount.new("10.00", :USDC)
    end
  end

  def test_unary_minus
    assert_equal Amount.new("-1", :USDC), -Amount.new("1", :USDC)
  end

  def test_abs
    assert_equal Amount.new("1", :USDC), Amount.new("-1", :USDC).abs
  end

  # name => [expected, amount, factor]
  {
    "integer" => ["3", "1", 3],
    "float" => ["1.5", "1", 1.5],
    "negative_by_negative" => ["2", "-1", -2],
    "bigdecimal" => ["3", "2", BigDecimal("1.5")],
    "rational" => ["3", "2", Rational(3, 2)]
  }.each do |name, (expected, amount, factor)|
    define_method("test_scalar_multiplication_by_#{name}") do
      assert_equal Amount.new(expected, :USDC), Amount.new(amount, :USDC) * factor
    end
  end

  def test_amount_times_amount_raises
    assert_raises(Amount::TypeMismatch) do
      Amount.new("1", :USDC) * Amount.new("1", :USDC)
    end
  end

  # name => [expected, amount, divisor]
  {
    "integer" => ["0.5", "1", 2],
    "negative_float" => ["2", "-1", -0.5],
    "rational" => ["2", "3", Rational(3, 2)],
    "bigdecimal" => ["2", "3", BigDecimal("1.5")]
  }.each do |name, (expected, amount, divisor)|
    define_method("test_scalar_division_by_#{name}_returns_amount") do
      assert_equal Amount.new(expected, :USDC), Amount.new(amount, :USDC) / divisor
    end
  end

  def test_amount_division_returns_ratio
    ratio = Amount.new("10", :USDC) / Amount.new("2", :USDC)

    assert_equal BigDecimal(5), ratio
  end

  def test_division_by_zero
    assert_raises(ZeroDivisionError) { Amount.new(1, :USDC) / 0 }
  end

  def test_cross_type_addition_via_explicit_conversion
    gold = Amount.new("0.0001", :GOLD)
    usdc = Amount.new("100", :USDC)
    result = gold + usdc.to(:GOLD, rate: "0.00000042")

    assert_equal BigDecimal("0.000142"), result.decimal
  end

  def test_arithmetic_returns_subclass
    register_gold_subclass!
    gold = GoldAmount.new("1", :GOLD)

    assert_instance_of GoldAmount, gold + gold
  end

  private

  def frozen_sum
    Amount.new("1", :USDC).freeze + Amount.new("2", :USDC).freeze
  end

  # Replaces the default registry with GOLD bound to GoldAmount.
  def register_gold_subclass!
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                           display_position: :suffix, ui_decimals: 4,
                           class: GoldAmount
  end
end
