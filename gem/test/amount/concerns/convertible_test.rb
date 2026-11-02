# frozen_string_literal: true

require "bigdecimal"
require_relative "../../test_helper"

class AmountConvertibleTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_to_same_symbol_is_identity
    amount = Amount.new("1", :USDC)

    assert_equal amount, amount.to(:USDC)
  end

  def test_to_with_explicit_rate_converts_value
    assert_equal BigDecimal("0.42"), Amount.new("1000", :USDC).to(:GOLD, rate: "0.00042").decimal
  end

  def test_to_with_explicit_rate_sets_target_symbol
    assert_equal :GOLD, Amount.new("1000", :USDC).to(:GOLD, rate: "0.00042").symbol
  end

  def test_to_with_rational_rate_converts_value
    assert_equal BigDecimal("2"), Amount.new("4", :USDC).to(:USD, rate: Rational(1, 2)).decimal
  end

  def test_to_with_rational_rate_sets_target_symbol
    assert_equal :USD, Amount.new("4", :USDC).to(:USD, rate: Rational(1, 2)).symbol
  end

  def test_to_without_rate_requires_default
    assert_raises(Amount::Registry::NoDefaultRate) do
      Amount.new("1", :USDC).to(:GOLD)
    end
  end

  def test_to_uses_registered_default_rate_value
    Amount.register_default_rate :USDC, :USD, 1

    assert_equal BigDecimal("1.5"), Amount.new("1.5", :USDC).to(:USD).decimal
  end

  def test_to_uses_registered_default_rate_symbol
    Amount.register_default_rate :USDC, :USD, 1

    assert_equal :USD, Amount.new("1.5", :USDC).to(:USD).symbol
  end
end
