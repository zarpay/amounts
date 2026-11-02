# frozen_string_literal: true

require_relative "test_helper"

class AmountTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_inspect_uses_default_ui_representation_for_prefix_type
    assert_equal "#<Amount USDC $1.50>", Amount.new("1.5", :USDC).inspect
  end

  def test_inspect_uses_default_ui_representation_for_suffix_type
    assert_equal "#<Amount GOLD 1.0000 oz t>", Amount.new("1", :GOLD).inspect
  end

  def test_unregistered_type_raises
    assert_raises(Amount::Registry::UnknownType) { Amount.new(1, :DOGE) }
  end

  def test_frozen_amount_renders_ui
    assert_equal "$1.50", frozen_amount.ui
  end

  def test_frozen_amount_renders_formatted
    assert_equal "1.500000", frozen_amount.formatted
  end

  def test_frozen_amount_renders_to_s
    assert_equal "USDC|1.50", frozen_amount.to_s
  end

  def test_very_large_atomic_value_preserves_atomic
    assert_equal 10**30, very_large_amount.atomic
  end

  def test_very_large_atomic_value_preserves_decimal
    assert_equal "1000000000000000000000.0", very_large_amount.decimal.to_s("F")
  end

  private

  def frozen_amount
    Amount.new("1.5", :USDC).freeze
  end

  def very_large_amount
    Amount.new(10**30, :SOL, from: :atomic)
  end
end
