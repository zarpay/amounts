# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/locale_test_setup"

class AmountLocalizationTest < Minitest::Test
  include LocaleTestSetup

  def test_localize_defaults_to_false
    refute_predicate Amount, :localize?
  end

  def test_setting_localize_true_makes_localize_predicate_true
    Amount.localize = true

    assert_predicate Amount, :localize?
  end

  def test_localize_is_an_alias_of_localize_predicate
    assert_equal :localize?, Amount.method(:localize).original_name
  end

  { "false" => false, "nil" => nil }.each do |name, value|
    define_method("test_setting_localize_#{name}_makes_localize_predicate_false") do
      Amount.localize = true
      Amount.localize = value

      assert_equal false, Amount.localize?
    end
  end

  def test_localize_true_without_i18n_raises_when_set
    without_i18n do
      assert_raises(ArgumentError) { Amount.localize = true }
    end
  end

  def test_localize_true_without_i18n_message_names_i18n
    without_i18n do
      assert_match(/i18n/, error_from(ArgumentError) { Amount.localize = true }.message)
    end
  end

  def test_localize_true_without_i18n_leaves_localize_off
    without_i18n do
      error_from(ArgumentError) { Amount.localize = true }

      refute_predicate Amount, :localize?
    end
  end

  def test_localize_true_without_i18n_leaves_ui_unlocalized
    without_i18n do
      error_from(ArgumentError) { Amount.localize = true }

      assert_equal "$1500.00", Amount.of_usd("1500").ui
    end
  end
end
