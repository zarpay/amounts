# frozen_string_literal: true

require_relative "../test_helper"

class AmountRegistryTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.send(:replace_registry, Amount::Registry.new) if Amount.registry.locked?
    Amount.registry.clear!
  end

  def test_registry_lock_marks_registry_locked
    Amount.registry.lock!

    assert Amount.registry.locked?
  end

  def test_registry_lock_prevents_register
    Amount.registry.lock!

    assert_raises(Amount::Registry::RegistryLocked) { Amount.register(:DOGE, decimals: 8) }
  end

  def test_registry_lock_prevents_register_default_rate
    Amount.registry.lock!

    assert_raises(Amount::Registry::RegistryLocked) { Amount.register_default_rate(:USD, :USDC, 1) }
  end

  def test_registry_lock_prevents_clear
    Amount.registry.lock!

    assert_raises(Amount::Registry::RegistryLocked) { Amount.registry.clear! }
  end

  def test_register_rejects_empty_symbol
    assert_raises(ArgumentError) { Amount.register :"", decimals: 2 }
  end

  def test_register_rejects_empty_symbol_with_message
    assert_match(/symbol must not be blank/, error_from(ArgumentError) { Amount.register :"", decimals: 2 }.message)
  end

  def test_register_rejects_nil_symbol
    assert_raises(ArgumentError) { Amount.register nil, decimals: 2 }
  end

  def test_registry_can_be_read_from_multiple_threads
    errors = Queue.new

    threads = 10.times.map do
      Thread.new do
        100.times do
          Amount.registry.lookup(:USDC)
          Amount.registry.default_rate?(:USDC, :USD)
        rescue StandardError => e
          errors << e
        end
      end
    end

    threads.each(&:join)

    assert errors.empty?, "expected no thread errors, got #{errors.size}"
  end

  def test_register_default_rate_accepts_rational
    Amount.register_default_rate :USDC, :USD, Rational(1, 2)

    assert_equal BigDecimal("0.5"), Amount.registry.default_rate(:USDC, :USD)
  end

  def test_register_default_rate_rational_converts_exactly
    Amount.register_default_rate :USDC, :USD, Rational(1, 2)

    assert_equal BigDecimal("0.5"), Amount.new("1", :USDC).to(:USD).decimal
  end

  def test_prefix_display_position_is_stored_as_its_template
    assert_equal "%u%n", Amount.registry.lookup(:USD).display_format
  end

  def test_suffix_display_position_is_stored_as_its_template
    assert_equal "%n %u", Amount.registry.lookup(:SOL).display_format
  end

  def test_display_position_defaults_to_suffix
    Amount.register :PTS, decimals: 0

    assert_equal :suffix, Amount.registry.lookup(:PTS).display_position
  end

  def test_default_display_position_is_stored_as_suffix_template
    Amount.register :PTS, decimals: 0

    assert_equal "%n %u", Amount.registry.lookup(:PTS).display_format
  end

  def test_display_format_leaves_display_position_unset
    Amount.register :EUR, decimals: 2, display_format: "%u%n"

    assert_nil Amount.registry.lookup(:EUR).display_position
  end

  def test_display_format_and_display_position_together_raise
    assert_raises(ArgumentError) { register_eur_with_format_and_position }
  end

  def test_display_format_and_display_position_together_message
    assert_match(/not both/, error_from(ArgumentError) { register_eur_with_format_and_position }.message)
  end

  def test_display_format_and_display_position_together_leave_type_unregistered
    error_from(ArgumentError) { register_eur_with_format_and_position }

    refute Amount.registry.registered?(:EUR)
  end

  {
    "string_without_number" => "%u",
    "symbol_with_only_number_marker" => :'%n'
  }.each do |name, format|
    define_method("test_display_format_#{name}_raises") do
      assert_raises(ArgumentError) { Amount.register :EUR, decimals: 2, display_format: format }
    end
  end

  def test_display_unit_format_and_position_together_raise
    assert_raises(Amount::Registry::InvalidDisplayUnit) do
      Amount.register :EUR, decimals: 2,
                            display_units: { cents: { scale: 100, format: "%n %u", position: :prefix } }
    end
  end

  def test_display_unit_format_without_number_raises
    assert_raises(Amount::Registry::InvalidDisplayUnit) do
      Amount.register :EUR, decimals: 2, display_units: { cents: { scale: 100, format: "%u" } }
    end
  end

  private

  def register_eur_with_format_and_position
    Amount.register :EUR, decimals: 2, display_format: "%u%n", display_position: :prefix
  end
end
