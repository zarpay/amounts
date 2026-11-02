# frozen_string_literal: true

require_relative "../../test_helper"

class AmountRegistryGeneratedConstructorsTest < Minitest::Test
  class GoldAmount < Amount
    def purity_estimate
      "24k"
    end
  end

  def setup
    AmountTestSupport.register_default_types!
  end

  def teardown
    Amount.singleton_class.send(:remove_method, :of_collide) if Amount.singleton_class.method_defined?(:of_collide)
    Amount.registry.clear!
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

  # Without the `of_` prefix the generated method would shadow
  # `Object#try` once ActiveSupport is loaded — see the :TRY regression.
  def test_generated_constructor_uses_of_prefix
    Amount.register :TRY, decimals: 2

    assert Amount.respond_to?(:of_try)
  end

  def test_of_prefixed_constructor_matches_new
    Amount.register :TRY, decimals: 2

    assert_equal Amount.new("100", :TRY), Amount.of_try("100")
  end

  def test_generated_constructor_exists_before_clear
    assert Amount.respond_to?(:of_usdc)
  end

  def test_clear_removes_generated_constructor_methods
    Amount.registry.clear!

    refute Amount.respond_to?(:of_usdc)
  end

  def test_constructor_collision_raises_at_registration_time
    Amount.singleton_class.send(:define_method, :of_collide) { :existing }

    assert_raises(Amount::Registry::AlreadyRegistered) do
      Amount.register :COLLIDE, decimals: 2
    end
  end

  def test_generated_constructor_returns_subclass
    use_gold_amount_registry!

    assert_instance_of GoldAmount, Amount.of_gold("1", from: :ui)
  end

  def test_generated_constructor_returns_subclass_with_its_behavior
    use_gold_amount_registry!

    assert_equal "24k", Amount.of_gold("1", from: :ui).purity_estimate
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
