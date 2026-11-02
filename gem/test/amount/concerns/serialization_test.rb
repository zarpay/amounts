# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

class AmountSerializationTest < Minitest::Test
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

  def test_to_h_and_load_round_trip_for_large_negative_amount
    amount = Amount.new(-(10**30), :USDC, from: :atomic)

    assert_equal amount, Amount.load(amount.to_h)
  end

  def test_to_h_returns_versioned_string_safe_payload
    assert_equal(
      { v: 1, atomic: "1500000", symbol: "USDC" },
      Amount.new("1.5", :USDC).to_h
    )
  end

  def test_load_accepts_legacy_unversioned_payload
    amount = Amount.load(atomic: 1_500_000, symbol: :USDC)

    assert_equal Amount.new("1.5", :USDC), amount
  end

  def test_load_without_atomic_raises_invalid_input
    assert_raises(Amount::InvalidInput) { Amount.load(v: 1, symbol: "USDC") }
  end

  def test_load_without_atomic_names_the_missing_key
    assert_match(/missing key: atomic/, error_from(Amount::InvalidInput) { Amount.load(v: 1, symbol: "USDC") }.message)
  end

  def test_load_empty_payload_raises_invalid_input
    assert_raises(Amount::InvalidInput) { Amount.load({}) }
  end

  def test_load_empty_payload_reports_missing_key
    assert_match(/missing key/, error_from(Amount::InvalidInput) { Amount.load({}) }.message)
  end

  def test_as_json_returns_compact_string
    assert_equal "USDC|1.50", Amount.new("1.5", :USDC).as_json
  end

  def test_to_json_returns_quoted_compact_string
    assert_equal '"USDC|1.50"', Amount.new("1.5", :USDC).to_json
  end

  def test_as_json_works_when_nested_in_hash
    hash = { amount: Amount.new("1.5", :USDC) }

    assert_equal({ "amount" => "USDC|1.50" }, JSON.parse(hash.to_json))
  end

  def test_load_rejects_unknown_serialization_version
    assert_raises(Amount::InvalidInput) do
      Amount.load(v: 2, atomic: "1500000", symbol: "USDC")
    end
  end

  def test_load_dispatches_to_registered_subclass
    assert_instance_of GoldAmount, restored_gold
  end

  def test_load_restores_subclass_behavior
    assert_equal "24k", restored_gold.purity_estimate
  end

  private

  def restored_gold
    register_gold_subclass!
    Amount.load(GoldAmount.new("1", :GOLD).to_h)
  end

  # Replaces the default registry with GOLD bound to GoldAmount.
  def register_gold_subclass!
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                           display_position: :suffix, ui_decimals: 4,
                           class: GoldAmount
  end
end
