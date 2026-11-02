# frozen_string_literal: true

require "bigdecimal"
require_relative "../test_helper"

class AmountDisplayTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  # name => [expected, value, symbol]
  {
    "usdc" => ["1.500000", "1.5", :USDC],
    "sol" => ["1.500000000", "1.5", :SOL],
    "logs" => ["1", 1, :LOGS]
  }.each do |name, (expected, value, symbol)|
    define_method("test_formatted_respects_storage_decimals_for_#{name}") do
      assert_equal expected, Amount.new(value, symbol).formatted
    end
  end

  # name => [expected, value, symbol]
  {
    "usdc" => ["$1.50", "1.5", :USDC],
    "usdc_rounded_down" => ["$1.56", "1.567", :USDC],
    "sol" => ["1.5000 SOL", "1.5", :SOL],
    "logs" => ["1 logs", 1, :LOGS]
  }.each do |name, (expected, value, symbol)|
    define_method("test_ui_respects_ui_decimals_and_position_for_#{name}") do
      assert_equal expected, Amount.new(value, symbol).ui
    end
  end

  def test_ui_ceil_direction
    assert_equal "$1.57", Amount.new("1.561", :USDC).ui(direction: :ceil)
  end

  # name => [expected, value, symbol]
  {
    "usdc" => ["1.50", "1.5", :USDC],
    "sol" => ["1.5000", "1.5", :SOL],
    "logs" => ["1", 1, :LOGS]
  }.each do |name, (expected, value, symbol)|
    define_method("test_ui_decorated_false_omits_the_display_symbol_for_#{name}") do
      assert_equal expected, Amount.new(value, symbol).ui(decorated: false)
    end
  end

  def test_ui_decorated_false_with_ceil_direction
    assert_equal "1.57", Amount.new("1.561", :USDC).ui(direction: :ceil, decorated: false)
  end

  # name => [expected, ui options]
  {
    "default_unit" => ["1.5000 oz t", {}],
    "gram" => ["46.65 g", { unit: :gram }],
    "kg" => ["0.04665 kg", { unit: :kg }]
  }.each do |name, (expected, options)|
    define_method("test_display_units_scale_output_in_#{name}") do
      assert_equal expected, Amount.new("1.5", :GOLD).ui(**options)
    end
  end

  # name => [expected, ui options]
  {
    "default_unit" => ["1.5000", { decorated: false }],
    "gram" => ["46.65", { unit: :gram, decorated: false }],
    "kg" => ["0.04665", { unit: :kg, decorated: false }]
  }.each do |name, (expected, options)|
    define_method("test_display_units_with_decorated_false_in_#{name}") do
      assert_equal expected, Amount.new("1.5", :GOLD).ui(**options)
    end
  end

  def test_in_unit_returns_raw_bigdecimal
    gold = Amount.new("1.0", :GOLD)

    assert_in_delta 31.1035, gold.in_unit(:gram).to_f, 0.0001
  end

  def test_unknown_display_unit_raises
    assert_raises(Amount::Registry::InvalidDisplayUnit) do
      Amount.new("1", :GOLD).ui(unit: :pound)
    end
  end

  # name => [expected, value, from]
  {
    "fraction" => ["2.5 TZ", "2.5", nil],
    "whole" => ["1 TZ", "1.0", nil],
    "zero" => ["0 TZ", "0.0", nil],
    "no_trailing_zeros" => ["1.123 TZ", "1.123", nil],
    "small_atomic" => ["0.00005 TZ", 50_000, :atomic]
  }.each do |name, (expected, value, from)|
    define_method("test_trim_zeros_strips_trailing_zeros_for_#{name}") do
      register_trim_zeros_type!
      amount = from ? Amount.new(value, :TZ, from:) : Amount.new(value, :TZ)

      assert_equal expected, amount.ui
    end
  end

  # name => [expected, value]
  {
    "fraction" => ["$1.50", "1.5"],
    "whole" => ["$1.00", "1.0"]
  }.each do |name, (expected, value)|
    define_method("test_trim_zeros_false_preserves_trailing_zeros_for_#{name}") do
      assert_equal expected, Amount.new(value, :USDC).ui
    end
  end

  # name => [expected, value]
  {
    "fraction" => ["2.5", "2.5"],
    "whole" => ["1", "1.0"]
  }.each do |name, (expected, value)|
    define_method("test_trim_zeros_with_decorated_false_for_#{name}") do
      register_trim_zeros_type!

      assert_equal expected, Amount.new(value, :TZ).ui(decorated: false)
    end
  end

  def test_trim_zeros_with_display_units
    Amount.register :TZG, decimals: 8, display_symbol: "oz t", display_position: :suffix,
                          trim_zeros: true,
                          display_units: { gram: { scale: "31.1035", symbol: "g", ui_decimals: 4 } }

    assert_equal "31.1035 g", Amount.new("1.0", :TZG).ui(unit: :gram)
  end

  def test_trim_zeros_display_unit_override
    Amount.register :TZO, decimals: 6, display_symbol: "T", display_position: :suffix,
                          trim_zeros: true,
                          display_units: { fixed: { scale: 1, symbol: "F", ui_decimals: 2, trim_zeros: false } }

    assert_equal "1.50 F", Amount.new("1.5", :TZO).ui(unit: :fixed)
  end

  def test_trim_zeros_call_site_true_strips_zeros
    assert_equal "1.5 SOL", Amount.new("1.5", :SOL).ui(trim_zeros: true)
  end

  def test_trim_zeros_call_site_false_keeps_zeros
    assert_equal "1.0000 SOL", Amount.new("1.0", :SOL).ui(trim_zeros: false)
  end

  def test_trim_zeros_call_site_overrides_registry
    Amount.register :TZR, decimals: 6, display_symbol: "T", display_position: :suffix, trim_zeros: true

    assert_equal "1.500000 T", Amount.new("1.5", :TZR).ui(trim_zeros: false)
  end

  def test_in_unit_with_rational_scale
    assert_equal BigDecimal("0.5"), rational_scale_metal.in_unit(:half)
  end

  def test_ui_with_rational_scale
    assert_match(/\A0\.50/, rational_scale_metal.ui(unit: :half))
  end

  private

  def register_trim_zeros_type!
    Amount.register :TZ, decimals: 9, display_symbol: "TZ", display_position: :suffix, trim_zeros: true
  end

  def rational_scale_metal
    Amount.registry.clear!
    Amount.register :METAL, decimals: 4, display_symbol: "x", display_position: :suffix,
                            ui_decimals: 2,
                            display_units: { half: { scale: Rational(1, 2), symbol: "h", ui_decimals: 2 } },
                            default_display: :half
    Amount.new("1", :METAL)
  end
end
