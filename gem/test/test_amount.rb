# frozen_string_literal: true

require "json"
require "i18n"
require_relative "test_helper"

class AmountTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_construct_from_integer_treats_as_atomic
    amount = Amount.new(1_000_000, :USDC)

    assert_equal 1_000_000, amount.atomic
    assert_equal BigDecimal("1"), amount.decimal
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

  def test_explicit_from_overrides_inference
    amount = Amount.new("1500000", :USDC, from: :atomic)

    assert_equal 1_500_000, amount.atomic
    assert_equal BigDecimal("1.5"), amount.decimal
  end

  def test_parse_roundtrips_to_s
    amount = Amount.parse("USDC|1.5")

    assert_equal 1_500_000, amount.atomic
    assert_equal "USDC|1.50", amount.to_s
  end

  def test_parse_accepts_explicit_v1_prefix
    amount = Amount.parse("v1:USDC|1.5")

    assert_equal Amount.new("1.5", :USDC), amount
  end

  def test_parse_rejects_unknown_version_prefix
    assert_raises(Amount::InvalidInput) { Amount.parse("v2:USDC|1.5") }
  end

  def test_generated_constructor_matches_new
    assert_equal Amount.new("1.50", :USDC), Amount.of_usdc("1.50")
  end

  def test_generated_constructor_accepts_from_keyword
    assert_equal 1_500_000, Amount.of_usdc(1_500_000, from: :atomic).atomic
  end

  def test_multi_word_symbol_generates_constructor
    Amount.register :OIL_WTI_BBL, decimals: 4

    assert_equal Amount.new("1.5", :OIL_WTI_BBL), Amount.of_oil_wti_bbl("1.5")
  end

  def test_non_method_safe_symbol_skips_constructor_generation
    Amount.register :'USDC.e', decimals: 6

    refute Amount.respond_to?(:of_usdc_e)
  end

  def test_generated_constructor_uses_of_prefix
    # Without the `of_` prefix the generated method would shadow
    # `Object#try` once ActiveSupport is loaded — see the :TRY regression.
    Amount.register :TRY, decimals: 2
    assert Amount.respond_to?(:of_try)
    assert_equal Amount.new("100", :TRY), Amount.of_try("100")
  end

  def test_clear_removes_generated_constructor_methods
    assert Amount.respond_to?(:of_usdc)

    Amount.registry.clear!

    refute Amount.respond_to?(:of_usdc)
  end

  def test_registry_lock_prevents_mutation
    Amount.registry.lock!

    assert Amount.registry.locked?
    assert_raises(Amount::Registry::RegistryLocked) { Amount.register(:DOGE, decimals: 8) }
    assert_raises(Amount::Registry::RegistryLocked) { Amount.register_default_rate(:USD, :USDC, 1) }
    assert_raises(Amount::Registry::RegistryLocked) { Amount.registry.clear! }
  ensure
    Amount.send(:replace_registry, Amount::Registry.new)
  end

  def test_constructor_collision_raises_at_registration_time
    Amount.singleton_class.send(:define_method, :of_collide) { :existing }

    assert_raises(Amount::Registry::AlreadyRegistered) do
      Amount.register :COLLIDE, decimals: 2
    end
  ensure
    Amount.singleton_class.send(:remove_method, :of_collide) if Amount.singleton_class.method_defined?(:of_collide)
  end

  def test_inspect_uses_default_ui_representation
    assert_equal "#<Amount USDC $1.50>", Amount.new("1.5", :USDC).inspect
    assert_equal "#<Amount GOLD 1.0000 oz t>", Amount.new("1", :GOLD).inspect
  end

  def test_parse_rejects_missing_value
    assert_raises(Amount::InvalidInput) { Amount.parse("USDC|") }
  end

  def test_parse_rejects_missing_symbol
    assert_raises(Amount::InvalidInput) { Amount.parse("|1.5") }
  end

  def test_unregistered_type_raises
    assert_raises(Amount::Registry::UnknownType) { Amount.new(1, :DOGE) }
  end

  def test_register_rejects_empty_symbol
    error = assert_raises(ArgumentError) { Amount.register :"", decimals: 2 }
    assert_match(/symbol must not be blank/, error.message)
  end

  def test_register_rejects_nil_symbol
    assert_raises(ArgumentError) { Amount.register nil, decimals: 2 }
  end

  def test_frozen_amount_renders_display
    amount = Amount.new("1.5", :USDC).freeze

    assert_equal "$1.50", amount.ui
    assert_equal "1.500000", amount.formatted
    assert_equal "USDC|1.50", amount.to_s
  end

  def test_frozen_amount_arithmetic_returns_unfrozen_result
    a = Amount.new("1", :USDC).freeze
    b = Amount.new("2", :USDC).freeze
    sum = a + b

    assert_equal Amount.new("3", :USDC), sum
    refute sum.frozen?
  end

  def test_formatted_respects_storage_decimals
    assert_equal "1.500000", Amount.new("1.5", :USDC).formatted
    assert_equal "1.500000000", Amount.new("1.5", :SOL).formatted
    assert_equal "1", Amount.new(1, :LOGS).formatted
  end

  def test_ui_respects_ui_decimals_and_position
    assert_equal "$1.50", Amount.new("1.5", :USDC).ui
    assert_equal "$1.56", Amount.new("1.567", :USDC).ui
    assert_equal "1.5000 SOL", Amount.new("1.5", :SOL).ui
    assert_equal "1 logs", Amount.new(1, :LOGS).ui
  end

  def test_ui_ceil_direction
    assert_equal "$1.57", Amount.new("1.561", :USDC).ui(direction: :ceil)
  end

  def test_ui_decorated_false_omits_the_display_symbol
    assert_equal "1.50", Amount.new("1.5", :USDC).ui(decorated: false)
    assert_equal "1.5000", Amount.new("1.5", :SOL).ui(decorated: false)
    assert_equal "1", Amount.new(1, :LOGS).ui(decorated: false)
  end

  def test_ui_decorated_false_with_ceil_direction
    assert_equal "1.57", Amount.new("1.561", :USDC).ui(direction: :ceil, decorated: false)
  end

  def test_display_units_scale_output
    gold = Amount.new("1.5", :GOLD)

    assert_equal "1.5000 oz t", gold.ui
    assert_equal "46.65 g", gold.ui(unit: :gram)
    assert_equal "0.04665 kg", gold.ui(unit: :kg)
  end

  def test_display_units_with_decorated_false
    gold = Amount.new("1.5", :GOLD)

    assert_equal "1.5000", gold.ui(decorated: false)
    assert_equal "46.65", gold.ui(unit: :gram, decorated: false)
    assert_equal "0.04665", gold.ui(unit: :kg, decorated: false)
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

  def test_trim_zeros_strips_trailing_zeros
    Amount.register :TZ, decimals: 9, display_symbol: "TZ", display_position: :suffix, trim_zeros: true

    assert_equal "2.5 TZ", Amount.new("2.5", :TZ).ui
    assert_equal "1 TZ", Amount.new("1.0", :TZ).ui
    assert_equal "0 TZ", Amount.new("0.0", :TZ).ui
    assert_equal "1.123 TZ", Amount.new("1.123", :TZ).ui
    assert_equal "0.00005 TZ", Amount.new(50_000, :TZ, from: :atomic).ui
  end

  def test_trim_zeros_false_preserves_trailing_zeros
    assert_equal "$1.50", Amount.new("1.5", :USDC).ui
    assert_equal "$1.00", Amount.new("1.0", :USDC).ui
  end

  def test_trim_zeros_with_decorated_false
    Amount.register :TZ, decimals: 9, display_symbol: "TZ", display_position: :suffix, trim_zeros: true

    assert_equal "2.5", Amount.new("2.5", :TZ).ui(decorated: false)
    assert_equal "1", Amount.new("1.0", :TZ).ui(decorated: false)
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

  def test_trim_zeros_call_site_override
    assert_equal "1.5 SOL", Amount.new("1.5", :SOL).ui(trim_zeros: true)
    assert_equal "1.0000 SOL", Amount.new("1.0", :SOL).ui(trim_zeros: false)
  end

  def test_trim_zeros_call_site_overrides_registry
    Amount.register :TZR, decimals: 6, display_symbol: "T", display_position: :suffix, trim_zeros: true

    assert_equal "1.500000 T", Amount.new("1.5", :TZR).ui(trim_zeros: false)
  end

  def test_predicates
    assert Amount.new(0, :USDC).zero?
    assert Amount.new(1, :USDC).positive?
    assert Amount.new(-1, :USDC).negative?
  end

  def test_same_type
    assert Amount.new(1, :USDC).same_type?(Amount.new(2, :USDC))
    refute Amount.new(1, :USDC).same_type?(Amount.new(1, :SOL))
    refute Amount.new(1, :USDC).same_type?(1)
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

  def test_asymmetric_rate_registration_only_allows_configured_direction
    Amount.register_default_rate :USD, :USDC, 1

    assert_equal Amount.new("15.00", :USDC), Amount.new("10.00", :USDC) + Amount.new("5.00", :USD)

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

  def test_scalar_multiplication
    assert_equal Amount.new("3", :USDC), Amount.new("1", :USDC) * 3
    assert_equal Amount.new("1.5", :USDC), Amount.new("1", :USDC) * 1.5
    assert_equal Amount.new("2", :USDC), Amount.new("-1", :USDC) * -2
    assert_equal Amount.new("3", :USDC), Amount.new("2", :USDC) * BigDecimal("1.5")
    assert_equal Amount.new("3", :USDC), Amount.new("2", :USDC) * Rational(3, 2)
  end

  def test_amount_times_amount_raises
    assert_raises(Amount::TypeMismatch) do
      Amount.new("1", :USDC) * Amount.new("1", :USDC)
    end
  end

  def test_scalar_division_returns_amount
    assert_equal Amount.new("0.5", :USDC), Amount.new("1", :USDC) / 2
    assert_equal Amount.new("2", :USDC), Amount.new("-1", :USDC) / -0.5
    assert_equal Amount.new("2", :USDC), Amount.new("3", :USDC) / Rational(3, 2)
    assert_equal Amount.new("2", :USDC), Amount.new("3", :USDC) / BigDecimal("1.5")
  end

  def test_amount_division_returns_ratio
    ratio = Amount.new("10", :USDC) / Amount.new("2", :USDC)

    assert_equal BigDecimal(5), ratio
  end

  def test_division_by_zero
    assert_raises(ZeroDivisionError) { Amount.new(1, :USDC) / 0 }
  end

  def test_split_preserves_total_exactly_with_remainder
    amount = Amount.new(10, :LOGS)
    parts, remainder = amount.split(3)

    assert_equal [3, 3, 3], parts.map(&:atomic)
    assert_equal 1, remainder.atomic
    assert_equal amount.atomic, parts.sum(&:atomic) + remainder.atomic
  end

  def test_split_even_division_returns_zero_remainder
    parts, remainder = Amount.new(9, :LOGS).split(3)

    assert_equal [3, 3, 3], parts.map(&:atomic)
    assert_equal 0, remainder.atomic
  end

  def test_split_one_returns_same_amount_and_zero_remainder
    parts, remainder = Amount.new(9, :LOGS).split(1)

    assert_equal [9], parts.map(&:atomic)
    assert_equal 0, remainder.atomic
  end

  def test_split_negative_amount_rounds_toward_zero_with_negative_remainder
    parts, remainder = Amount.new(-10, :LOGS).split(3)

    assert_equal [-3, -3, -3], parts.map(&:atomic)
    assert_equal(-1, remainder.atomic)
    assert_equal(-10, parts.sum(&:atomic) + remainder.atomic)
  end

  def test_allocate_by_weights
    amount = Amount.new(100, :LOGS)
    parts, remainder = amount.allocate([1, 1, 2])

    assert_equal [25, 25, 50], parts.map(&:atomic)
    assert_equal 0, remainder.atomic
    assert_equal amount.atomic, parts.sum(&:atomic) + remainder.atomic
  end

  def test_allocate_remainder_is_explicit
    parts, remainder = Amount.new(10, :LOGS).allocate([1, 1, 1])

    assert_equal [3, 3, 3], parts.map(&:atomic)
    assert_equal 1, remainder.atomic
  end

  def test_allocate_allows_zero_weights
    parts, remainder = Amount.new(10, :LOGS).allocate([0, 1])

    assert_equal [0, 10], parts.map(&:atomic)
    assert_equal 0, remainder.atomic
  end

  def test_allocate_negative_amount_rounds_toward_zero_with_negative_remainder
    parts, remainder = Amount.new(-10, :LOGS).allocate([1, 1, 1])

    assert_equal [-3, -3, -3], parts.map(&:atomic)
    assert_equal(-1, remainder.atomic)
    assert_equal(-10, parts.sum(&:atomic) + remainder.atomic)
  end

  def test_comparison_same_type
    left = Amount.new("1", :USDC)
    right = Amount.new("2", :USDC)

    assert left < right
    assert right > left
    assert_equal Amount.new("1", :USDC), left
  end

  def test_comparison_cross_type_uses_registered_rate
    Amount.register_default_rate :USD, :USDC, 1

    assert_operator Amount.new("10.00", :USDC), :>, Amount.new("5.00", :USD)
    assert_equal 0, Amount.new("5.00", :USDC) <=> Amount.new("5.00", :USD)
  end

  def test_comparison_different_type_nil_without_rate
    assert_nil(Amount.new(1, :USDC) <=> Amount.new(1, :SOL))
  end

  def test_sorting
    amounts = [Amount.new("3", :USDC), Amount.new("1", :USDC), Amount.new("2", :USDC)]

    assert_equal ["1.0", "2.0", "3.0"], amounts.sort.map { |amount| amount.decimal.to_s("F") }
  end

  def test_to_same_symbol_is_identity
    amount = Amount.new("1", :USDC)

    assert_equal amount, amount.to(:USDC)
  end

  def test_to_with_explicit_rate
    gold = Amount.new("1000", :USDC).to(:GOLD, rate: "0.00042")

    assert_equal BigDecimal("0.42"), gold.decimal
    assert_equal :GOLD, gold.symbol
  end

  def test_to_with_rational_rate
    converted = Amount.new("4", :USDC).to(:USD, rate: Rational(1, 2))

    assert_equal BigDecimal("2"), converted.decimal
    assert_equal :USD, converted.symbol
  end

  def test_register_default_rate_accepts_rational
    Amount.register_default_rate :USDC, :USD, Rational(1, 2)

    assert_equal BigDecimal("0.5"), Amount.registry.default_rate(:USDC, :USD)
    assert_equal BigDecimal("0.5"), Amount.new("1", :USDC).to(:USD).decimal
  end

  def test_display_units_with_rational_scale
    Amount.registry.clear!
    Amount.register :METAL, decimals: 4, display_symbol: "x", display_position: :suffix,
      ui_decimals: 2,
      display_units: { half: { scale: Rational(1, 2), symbol: "h", ui_decimals: 2 } },
      default_display: :half

    metal = Amount.new("1", :METAL)

    assert_equal BigDecimal("0.5"), metal.in_unit(:half)
    assert_match(/\A0\.50/, metal.ui(unit: :half))
  end

  def test_to_without_rate_requires_default
    assert_raises(Amount::Registry::NoDefaultRate) do
      Amount.new("1", :USDC).to(:GOLD)
    end
  end

  def test_to_uses_registered_default_rate
    Amount.register_default_rate :USDC, :USD, 1

    usd = Amount.new("1.5", :USDC).to(:USD)

    assert_equal BigDecimal("1.5"), usd.decimal
    assert_equal :USD, usd.symbol
  end

  def test_cross_type_addition_via_explicit_conversion
    gold = Amount.new("0.0001", :GOLD)
    usdc = Amount.new("100", :USDC)
    result = gold + usdc.to(:GOLD, rate: "0.00000042")

    assert_equal BigDecimal("0.000142"), result.decimal
  end

  def test_hash_equality_semantics
    one = Amount.new("1.5", :USDC)
    two = Amount.new("1.5", :USDC)
    three = Amount.new("1.5", :USD)

    data = { one => :first }

    assert_equal :first, data[two]
    assert_nil data[three]
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

  def test_load_wraps_missing_keys_as_invalid_input
    error = assert_raises(Amount::InvalidInput) { Amount.load(v: 1, symbol: "USDC") }
    assert_match(/missing key: atomic/, error.message)

    error = assert_raises(Amount::InvalidInput) { Amount.load({}) }
    assert_match(/missing key/, error.message)
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

  def test_very_large_atomic_value_preserves_precision
    amount = Amount.new(10**30, :SOL, from: :atomic)

    assert_equal 10**30, amount.atomic
    assert_equal "1000000000000000000000.0", amount.decimal.to_s("F")
  end

  def test_registry_can_be_read_from_multiple_threads
    errors = Queue.new

    threads = 10.times.map do
      Thread.new do
        100.times do
          Amount.registry.lookup(:USDC)
          Amount.registry.default_rate?(:USDC, :USD)
        rescue StandardError => error
          errors << error
        end
      end
    end

    threads.each(&:join)

    assert errors.empty?, "expected no thread errors, got #{errors.size}"
  end
end

class AmountCustomClassTest < Minitest::Test
  class GoldAmount < Amount
    def purity_estimate
      "24k"
    end
  end

  def setup
    Amount.registry.clear!
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                     display_position: :suffix, ui_decimals: 4,
                     class: GoldAmount
  end

  def teardown
    Amount.registry.clear!
  end

  def test_subclass_instance_from_own_new
    gold = GoldAmount.new("1", :GOLD)

    assert_instance_of GoldAmount, gold
    assert_equal "24k", gold.purity_estimate
  end

  def test_arithmetic_returns_subclass
    gold = GoldAmount.new("1", :GOLD)

    assert_instance_of GoldAmount, gold + gold
  end

  def test_generated_constructor_returns_subclass
    gold = Amount.of_gold("1", from: :ui)

    assert_instance_of GoldAmount, gold
    assert_equal "24k", gold.purity_estimate
  end

  def test_split_returns_subclass_parts_and_remainder
    parts, remainder = GoldAmount.new("3", :GOLD).split(2)

    assert parts.all? { |part| part.instance_of?(GoldAmount) }
    assert_instance_of GoldAmount, remainder
  end

  def test_amount_new_dispatches_to_registered_subclass
    assert_instance_of GoldAmount, Amount.new("1", :GOLD)
    assert_instance_of GoldAmount, Amount.new(100_000_000, :GOLD, from: :atomic)
  end

  def test_parse_dispatches_to_registered_subclass
    assert_instance_of GoldAmount, Amount.parse("GOLD|1.0")
  end

  def test_load_dispatches_to_registered_subclass
    payload = GoldAmount.new("1", :GOLD).to_h
    restored = Amount.load(payload)

    assert_instance_of GoldAmount, restored
    assert_equal "24k", restored.purity_estimate
  end

  def test_explicit_wrong_subclass_still_raises
    other = Class.new(Amount)

    error = assert_raises(Amount::InvalidInput) { other.new("1", :GOLD) }
    assert_match(/use AmountCustomClassTest::GoldAmount\.new for GOLD/, error.message)
  end

  def test_amount_new_with_default_class_is_unchanged
    Amount.register :USDC, decimals: 6
    instance = Amount.new("1", :USDC)

    assert_instance_of Amount, instance
  end
end

class AmountLocaleTest < Minitest::Test
  def setup
    AmountTestSupport.register_default_types!
    @previous_locale = I18n.locale
    @previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = %i[en de fr xx]
    I18n.backend.store_translations(:en, number: { format: { delimiter: ",", separator: "." } })
    I18n.backend.store_translations(:de, number: { format: { delimiter: ".", separator: "," } })
    I18n.backend.store_translations(:fr, number: { format: { delimiter: " ", separator: "," } })
    Amount.localize = false
  end

  def teardown
    Amount.localize = false
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    Amount.registry.clear!
  end

  def test_not_localizing_is_unchanged
    assert_equal "$122500.00", Amount.of_usd("122500").ui
    assert_equal "-$1234.50".sub("$", ""), Amount.of_usd("-1234.50").ui.sub("$", "")
    assert_equal "1500 logs", Amount.of_logs(1500).ui
    refute_predicate Amount, :localize?
  end

  def test_locale_option_formats_en_and_de
    assert_equal "$122,500.00", Amount.of_usd("122500").ui(locale: :en)
    assert_equal "$122.500,00", Amount.of_usd("122500").ui(locale: :de)
    assert_equal "$122 500,00", Amount.of_usd("122500").ui(locale: :fr)
  end

  def test_locale_under_one_thousand_and_negative
    assert_equal "$999,99", Amount.of_usd("999.99").ui(locale: :de)
    assert_equal "$-1.234.567,50", Amount.of_usd("-1234567.50").ui(locale: :de)
    assert_equal "$-1,234.50", Amount.of_usd("-1234.50").ui(locale: :en)
    assert_equal "$-123.00", Amount.of_usd("-123").ui(locale: :en)
  end

  def test_locale_with_decimals_zero_type
    assert_equal "1,500 logs", Amount.of_logs(1500).ui(locale: :en)
    assert_equal "1.500.000 logs", Amount.of_logs(1_500_000).ui(locale: :de)
  end

  def test_locale_with_trim_zeros
    assert_equal "1.234,5 SOL", Amount.of_sol("1234.5").ui(locale: :de, trim_zeros: true)
    assert_equal "1.000 SOL", Amount.of_sol("1000").ui(locale: :de, trim_zeros: true)
  end

  def test_locale_with_direction
    assert_equal "$1.234,56", Amount.of_usdc("1234.5678").ui(locale: :de)
    assert_equal "$1.234,57", Amount.of_usdc("1234.5678").ui(locale: :de, direction: :ceil)
  end

  def test_locale_with_display_unit_and_undecorated
    gold = Amount.of_gold("1000")

    assert_equal "31.103,50 g", gold.ui(unit: :gram, locale: :de)
    assert_equal "31,103.50", gold.ui(unit: :gram, decorated: false, locale: :en)
    assert_equal "1.000,0000", gold.ui(decorated: false, locale: :de)
  end

  def test_localize_uses_i18n_locale
    Amount.localize = true
    I18n.locale = :de

    assert_equal "$1.500,00", Amount.of_usd("1500").ui
    assert_equal "$1,500.00", Amount.of_usd("1500").ui(locale: :en)
  end

  def test_missing_keys_fall_back
    assert_equal "$1,500.00", Amount.of_usd("1500").ui(locale: :xx)
    I18n.backend.store_translations(:xx, number: { format: { separator: "," } })

    assert_equal "$1,500,00", Amount.of_usd("1500").ui(locale: :xx)
  end

  def test_wire_formats_do_not_change
    Amount.localize = true
    I18n.locale = :de
    amount = Amount.of_usd("122500.5")

    assert_equal "USD|122500.50", amount.to_s
    assert_equal "122500.50", amount.formatted
    assert_equal Amount.of_usd("122500.5"), Amount.parse(amount.to_s)
  end

  def test_type_label_fallback_chain
    Amount.register :SEARCHES, decimals: 0, display_symbol: "searches-sym"
    Amount.register :CREDITS, decimals: 0, display_symbol: "cr", label_key: :'custom.credits'
    searches = Amount.new(3, :SEARCHES)
    credits = Amount.new(3, :CREDITS)

    # 3. nothing translated: display_symbol
    assert_equal "3 searches-sym", searches.ui(locale: :en)
    assert_equal "searches-sym", searches.unit_label(locale: :en)

    # 2. conventional key
    I18n.backend.store_translations(:en, amounts: { units: { searches: "searches", credits: "conv" } })
    assert_equal "3 searches", searches.ui(locale: :en)
    assert_equal "searches", searches.unit_label(locale: :en)

    # 1. label_key wins over the conventional key; a missing label_key falls back to display_symbol
    assert_equal "3 cr", credits.ui(locale: :en)
    I18n.backend.store_translations(:en, custom: { credits: "credits" })
    assert_equal "3 credits", credits.ui(locale: :en)
  end

  def test_two_locales_two_labels
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:en, amounts: { units: { searches: "searches" } })
    I18n.backend.store_translations(:de, amounts: { units: { searches: "Suchen" } })
    amount = Amount.new(1500, :SEARCHES)

    assert_equal "1,500 searches", amount.ui(locale: :en)
    assert_equal "1.500 Suchen", amount.ui(locale: :de)
    assert_equal "Suchen", amount.unit_label(locale: :de)
  end

  def test_labels_unchanged_when_not_localizing
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:en, amounts: { units: { searches: "translated" } })

    assert_equal "3 SEARCHES", Amount.new(3, :SEARCHES).ui
    assert_equal "SEARCHES", Amount.new(3, :SEARCHES).unit_label
    assert_equal "g", Amount.of_gold("1").unit_label(unit: :gram)
  end

  def test_localize_uses_i18n_locale_for_labels
    Amount.register :SEARCHES, decimals: 0
    I18n.backend.store_translations(:de, amounts: { units: { searches: "Suchen" } })
    Amount.localize = true
    I18n.locale = :de

    assert_equal "3 Suchen", Amount.new(3, :SEARCHES).ui
    assert_equal "Suchen", Amount.new(3, :SEARCHES).unit_label
  end

  def test_display_unit_label_fallback_chain
    gold = Amount.of_gold("1000")

    # no translation: unit :symbol
    assert_equal "31.103,50 g", gold.ui(unit: :gram, locale: :de)
    assert_equal "g", gold.unit_label(unit: :gram, locale: :de)

    # conventional key
    I18n.backend.store_translations(:de, amounts: { display_units: { gold: { gram: "Gramm" } } })
    assert_equal "31.103,50 Gramm", gold.ui(unit: :gram, locale: :de)
    assert_equal "Gramm", gold.unit_label(unit: :gram, locale: :de)
    assert_equal "g", gold.unit_label(unit: :gram, locale: :en)
  end

  def test_display_unit_label_key_and_type_label_fallback
    Amount.register :MASS, decimals: 2, display_symbol: "mass", display_units: {
      kilo: { scale: 1, label_key: "my.kilo" },
      plain: { scale: 1 }
    }
    mass = Amount.new("1", :MASS)

    # no spec :symbol and no key: type label (display_symbol)
    assert_equal "mass", mass.unit_label(unit: :plain, locale: :en)
    assert_equal "mass", mass.unit_label(unit: :kilo, locale: :en)

    I18n.backend.store_translations(:en, amounts: { units: { mass: "Mass" } })
    assert_equal "Mass", mass.unit_label(unit: :plain, locale: :en)

    I18n.backend.store_translations(:en, my: { kilo: "kg" })
    assert_equal "1.00 kg", mass.ui(unit: :kilo, locale: :en)
  end

  def test_unit_label_errors
    assert_raises(Amount::Registry::InvalidDisplayUnit) { Amount.of_gold("1").unit_label(unit: :nope) }
    without_i18n do
      assert_raises(ArgumentError) { Amount.of_usd("1").unit_label(locale: :de) }
    end
  end

  def test_locale_without_i18n_raises
    without_i18n do
      error = assert_raises(ArgumentError) { Amount.of_usd("1").ui(locale: :de) }
      assert_match(/i18n/, error.message)
    end
  end

  def test_localize_true_without_i18n_raises_when_set
    without_i18n do
      error = assert_raises(ArgumentError) { Amount.localize = true }
      assert_match(/i18n/, error.message)
      refute_predicate Amount, :localize?
      assert_equal "$1500.00", Amount.of_usd("1500").ui
    end
  end

  private

  def without_i18n
    i18n = Object.send(:remove_const, :I18n)
    yield
  ensure
    Object.const_set(:I18n, i18n)
  end
end
