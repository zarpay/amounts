# frozen_string_literal: true

require_relative "../../test_helper"

class AmountConstructibleTest < Minitest::Test
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

  def test_construct_from_integer_treats_as_atomic
    assert_equal 1_000_000, Amount.new(1_000_000, :USDC).atomic
  end

  def test_construct_from_integer_gives_matching_decimal
    assert_equal BigDecimal("1"), Amount.new(1_000_000, :USDC).decimal
  end

  def test_construct_from_string_treats_as_ui
    assert_equal 1_500_000, Amount.new("1.50", :USDC).atomic
  end

  def test_construct_from_float_treats_as_decimal
    assert_equal 1_500_000, Amount.new(1.5, :USDC).atomic
  end

  def test_construct_from_rational_treats_as_ui
    assert_equal 1_500_000, Amount.new(Rational(3, 2), :USDC).atomic
  end

  def test_construct_from_rational_is_exact_for_repeating_fractions
    # 1/3 has no finite decimal expansion. With six decimals of storage
    # the atomic representation is 333333 (truncated toward zero).
    assert_equal 333_333, Amount.new(Rational(1, 3), :USDC).atomic
  end

  def test_construct_from_rational_with_explicit_ui_from
    assert_equal 1_500_000, Amount.new(Rational(3, 2), :USDC, from: :ui).atomic
  end

  def test_explicit_from_overrides_inference_for_atomic
    assert_equal 1_500_000, Amount.new("1500000", :USDC, from: :atomic).atomic
  end

  def test_explicit_from_overrides_inference_for_decimal
    assert_equal BigDecimal("1.5"), Amount.new("1500000", :USDC, from: :atomic).decimal
  end

  def test_subclass_instance_from_own_new
    use_gold_amount_registry!

    assert_instance_of GoldAmount, GoldAmount.new("1", :GOLD)
  end

  def test_subclass_instance_from_own_new_has_subclass_behavior
    use_gold_amount_registry!

    assert_equal "24k", GoldAmount.new("1", :GOLD).purity_estimate
  end

  def test_amount_new_dispatches_to_registered_subclass_from_ui
    use_gold_amount_registry!

    assert_instance_of GoldAmount, Amount.new("1", :GOLD)
  end

  def test_amount_new_dispatches_to_registered_subclass_from_atomic
    use_gold_amount_registry!

    assert_instance_of GoldAmount, Amount.new(100_000_000, :GOLD, from: :atomic)
  end

  def test_explicit_wrong_subclass_still_raises
    use_gold_amount_registry!
    other = Class.new(Amount)

    assert_raises(Amount::InvalidInput) { other.new("1", :GOLD) }
  end

  def test_explicit_wrong_subclass_message_names_registered_class
    use_gold_amount_registry!
    other = Class.new(Amount)

    assert_match(/use AmountConstructibleTest::GoldAmount\.new for GOLD/,
                 error_from(Amount::InvalidInput) { other.new("1", :GOLD) }.message)
  end

  def test_amount_new_with_default_class_is_unchanged
    use_gold_amount_registry!
    Amount.register :USDC, decimals: 6

    assert_instance_of Amount, Amount.new("1", :USDC)
  end

  private

  # Replaces the default types with GOLD registered to {GoldAmount}.
  def use_gold_amount_registry!
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                           display_position: :suffix, ui_decimals: 4,
                           class: GoldAmount
  end
end
