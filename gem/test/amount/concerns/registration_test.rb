# frozen_string_literal: true

require_relative "../../test_helper"

class AmountRegistrationTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_registry_returns_the_same_object_on_repeated_calls
    assert_same Amount.registry, Amount.registry
  end

  def test_subclass_shares_amount_registry
    assert_same Amount.registry, Class.new(Amount).registry
  end

  def test_register_adds_a_type
    Amount.register :PTS, decimals: 0

    assert_equal :PTS, Amount.registry.lookup(:PTS).symbol
  end

  def test_register_default_rate_stores_the_rate
    Amount.register_default_rate :USD, :USDC, "1"

    assert_equal BigDecimal("1"), Amount.registry.default_rate(:USD, :USDC)
  end

  def test_with_registry_activates_the_given_registry_inside_the_block
    temporary = Amount::Registry.new

    assert_same temporary, Amount.with_registry(temporary) { Amount.registry }
  end

  def test_with_registry_restores_the_original_registry_afterwards
    original = Amount.registry
    Amount.with_registry(Amount::Registry.new) { nil }

    assert_same original, Amount.registry
  end

  def test_with_registry_restores_the_original_registry_when_the_block_raises
    original = Amount.registry
    error_from(RuntimeError) { Amount.with_registry(Amount::Registry.new) { raise "boom" } }

    assert_same original, Amount.registry
  end

  def test_with_registry_returns_the_block_value
    assert_equal :result, Amount.with_registry(Amount::Registry.new) { :result }
  end

  def test_with_registry_removes_outgoing_generated_constructors_inside_the_block
    refute Amount.with_registry(Amount::Registry.new) { Amount.respond_to?(:of_usdc) }
  end

  def test_with_registry_restores_outgoing_generated_constructors_afterwards
    Amount.with_registry(Amount::Registry.new) { nil }

    assert Amount.respond_to?(:of_usdc)
  end
end
