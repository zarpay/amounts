# frozen_string_literal: true

require_relative "../../test_helper"

class AmountComparisonTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_zero_predicate
    assert Amount.new(0, :USDC).zero?
  end

  def test_positive_predicate
    assert Amount.new(1, :USDC).positive?
  end

  def test_negative_predicate
    assert Amount.new(-1, :USDC).negative?
  end

  def test_same_type_true_for_same_symbol
    assert Amount.new(1, :USDC).same_type?(Amount.new(2, :USDC))
  end

  def test_same_type_false_for_different_symbol
    refute Amount.new(1, :USDC).same_type?(Amount.new(1, :SOL))
  end

  def test_same_type_false_for_non_amount
    refute Amount.new(1, :USDC).same_type?(1)
  end

  def test_less_than_same_type
    assert Amount.new("1", :USDC) < Amount.new("2", :USDC)
  end

  def test_greater_than_same_type
    assert Amount.new("2", :USDC) > Amount.new("1", :USDC)
  end

  def test_equality_same_type
    assert_equal Amount.new("1", :USDC), Amount.new("1", :USDC)
  end

  def test_greater_than_cross_type_uses_registered_rate
    Amount.register_default_rate :USD, :USDC, 1

    assert_operator Amount.new("10.00", :USDC), :>, Amount.new("5.00", :USD)
  end

  def test_spaceship_cross_type_uses_registered_rate
    Amount.register_default_rate :USD, :USDC, 1

    assert_equal 0, Amount.new("5.00", :USDC) <=> Amount.new("5.00", :USD)
  end

  def test_comparison_different_type_nil_without_rate
    assert_nil(Amount.new(1, :USDC) <=> Amount.new(1, :SOL))
  end

  def test_sorting
    amounts = [Amount.new("3", :USDC), Amount.new("1", :USDC), Amount.new("2", :USDC)]

    assert_equal ["1.0", "2.0", "3.0"], amounts.sort.map { |amount| amount.decimal.to_s("F") }
  end

  def test_equal_amounts_are_the_same_hash_key
    data = { Amount.new("1.5", :USDC) => :first }

    assert_equal :first, data[Amount.new("1.5", :USDC)]
  end

  def test_different_symbol_is_a_different_hash_key
    data = { Amount.new("1.5", :USDC) => :first }

    assert_nil data[Amount.new("1.5", :USD)]
  end
end
