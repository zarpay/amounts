# frozen_string_literal: true

require_relative "../../test_helper"

class AmountAllocationTest < Minitest::Test
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

  def test_split_with_remainder_parts
    parts, = Amount.new(10, :LOGS).split(3)

    assert_equal [3, 3, 3], parts.map(&:atomic)
  end

  def test_split_with_remainder_remainder
    _, remainder = Amount.new(10, :LOGS).split(3)

    assert_equal 1, remainder.atomic
  end

  def test_split_with_remainder_preserves_total
    parts, remainder = Amount.new(10, :LOGS).split(3)

    assert_equal 10, parts.sum(&:atomic) + remainder.atomic
  end

  def test_split_even_division_parts
    parts, = Amount.new(9, :LOGS).split(3)

    assert_equal [3, 3, 3], parts.map(&:atomic)
  end

  def test_split_even_division_returns_zero_remainder
    _, remainder = Amount.new(9, :LOGS).split(3)

    assert_equal 0, remainder.atomic
  end

  def test_split_one_returns_same_amount
    parts, = Amount.new(9, :LOGS).split(1)

    assert_equal [9], parts.map(&:atomic)
  end

  def test_split_one_returns_zero_remainder
    _, remainder = Amount.new(9, :LOGS).split(1)

    assert_equal 0, remainder.atomic
  end

  def test_split_negative_amount_parts_round_toward_zero
    parts, = Amount.new(-10, :LOGS).split(3)

    assert_equal [-3, -3, -3], parts.map(&:atomic)
  end

  def test_split_negative_amount_has_negative_remainder
    _, remainder = Amount.new(-10, :LOGS).split(3)

    assert_equal(-1, remainder.atomic)
  end

  def test_split_negative_amount_preserves_total
    parts, remainder = Amount.new(-10, :LOGS).split(3)

    assert_equal(-10, parts.sum(&:atomic) + remainder.atomic)
  end

  def test_allocate_by_weights_parts
    parts, = Amount.new(100, :LOGS).allocate([1, 1, 2])

    assert_equal [25, 25, 50], parts.map(&:atomic)
  end

  def test_allocate_by_weights_zero_remainder
    _, remainder = Amount.new(100, :LOGS).allocate([1, 1, 2])

    assert_equal 0, remainder.atomic
  end

  def test_allocate_by_weights_preserves_total
    parts, remainder = Amount.new(100, :LOGS).allocate([1, 1, 2])

    assert_equal 100, parts.sum(&:atomic) + remainder.atomic
  end

  def test_allocate_uneven_parts
    parts, = Amount.new(10, :LOGS).allocate([1, 1, 1])

    assert_equal [3, 3, 3], parts.map(&:atomic)
  end

  def test_allocate_remainder_is_explicit
    _, remainder = Amount.new(10, :LOGS).allocate([1, 1, 1])

    assert_equal 1, remainder.atomic
  end

  def test_allocate_allows_zero_weights
    parts, = Amount.new(10, :LOGS).allocate([0, 1])

    assert_equal [0, 10], parts.map(&:atomic)
  end

  def test_allocate_with_zero_weight_has_zero_remainder
    _, remainder = Amount.new(10, :LOGS).allocate([0, 1])

    assert_equal 0, remainder.atomic
  end

  def test_allocate_negative_amount_parts_round_toward_zero
    parts, = Amount.new(-10, :LOGS).allocate([1, 1, 1])

    assert_equal [-3, -3, -3], parts.map(&:atomic)
  end

  def test_allocate_negative_amount_has_negative_remainder
    _, remainder = Amount.new(-10, :LOGS).allocate([1, 1, 1])

    assert_equal(-1, remainder.atomic)
  end

  def test_allocate_negative_amount_preserves_total
    parts, remainder = Amount.new(-10, :LOGS).allocate([1, 1, 1])

    assert_equal(-10, parts.sum(&:atomic) + remainder.atomic)
  end

  def test_split_returns_subclass_parts
    parts, = gold_split

    assert parts.all? { |part| part.instance_of?(GoldAmount) }
  end

  def test_split_returns_subclass_remainder
    _, remainder = gold_split

    assert_instance_of GoldAmount, remainder
  end

  private

  def gold_split
    register_gold_subclass!
    GoldAmount.new("3", :GOLD).split(2)
  end

  # Replaces the default registry with GOLD bound to GoldAmount.
  def register_gold_subclass!
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                           display_position: :suffix, ui_decimals: 4,
                           class: GoldAmount
  end
end
