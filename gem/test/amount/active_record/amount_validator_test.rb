# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordAmountValidatorTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_accepts_valid_multi_symbol_amount
    assert validated(amount: "USDC|100.00").valid?
  end

  def test_rejects_wrong_symbol
    refute validated(amount: "USD|100.00").valid?
  end

  def test_reports_wrong_symbol
    assert_includes errors_on(validated(amount: "USD|100.00"), :amount), "must have symbol USDC"
  end

  def test_rejects_amount_below_lower_bound
    refute validated(amount: "USDC|0.00").valid?
  end

  def test_reports_amount_below_lower_bound
    assert_includes errors_on(validated(amount: "USDC|0.00"), :amount), "must be greater than USDC|0.00"
  end

  def test_rejects_amount_above_upper_bound
    refute validated(amount: "USDC|1000.01").valid?
  end

  def test_reports_amount_above_upper_bound
    assert_includes errors_on(validated(amount: "USDC|1000.01"), :amount), "must be less than or equal to USDC|1000.00"
  end

  def test_allows_nil_when_allow_nil_is_set
    assert validated(amount: "USDC|100.00", fee: nil).valid?
  end

  def test_supports_fixed_symbol_numeric_thresholds
    assert validated(amount: "USDC|100.00", fee: 0.5).valid?
  end

  def test_rejects_fixed_symbol_amount_below_lower_bound
    refute validated(amount: "USDC|100.00", fee: 0).valid?
  end

  def test_reports_fixed_symbol_amount_below_lower_bound
    assert_includes errors_on(validated(amount: "USDC|100.00", fee: 0), :fee), "must be greater than SOL|0.0000"
  end

  def test_rejects_fixed_symbol_amount_at_exclusive_upper_bound
    refute validated(amount: "USDC|100.00", fee: 10).valid?
  end

  def test_reports_fixed_symbol_amount_at_exclusive_upper_bound
    assert_includes errors_on(validated(amount: "USDC|100.00", fee: 10), :fee), "must be less than SOL|10.0000"
  end

  def test_rejects_cross_type_threshold_without_rate
    refute cross_type_threshold_model.new(amount: "USDC|2.00").valid?
  end

  def test_reports_cross_type_threshold_without_rate
    holding = cross_type_threshold_model.new(amount: "USDC|2.00")

    assert_includes errors_on(holding, :amount), "cannot compare USDC to USD for greater_than"
  end

  def test_adds_symbol_error_by_key_with_interpolations
    holding = validated(amount: "USD|100.00")
    holding.valid?

    assert_includes holding.errors.details[:amount], { error: :amount_symbol, expected: :USDC }
  end

  def test_adds_comparison_error_by_key_with_interpolations
    holding = validated(amount: "USDC|0.00")
    holding.valid?

    assert_includes holding.errors.details[:amount], { error: :greater_than, count: "USDC|0.00" }
  end

  def test_incomparable_error_details
    holding = cross_type_threshold_model.new(amount: "USDC|2.00")
    holding.valid?

    assert_includes holding.errors.details[:amount],
                    { error: :amount_incomparable, symbol: :USDC, other_symbol: :USD, option: :greater_than }
  end

  def test_symbol_message_can_be_translated_by_the_app
    messages = with_german_messages { errors_on(validated(amount: "USD|100.00"), :amount) }

    assert_includes messages, "muss das Symbol USDC haben"
  end

  def test_comparison_message_can_be_translated_by_the_app
    messages = with_german_messages { errors_on(validated(amount: "USDC|0.00"), :amount) }

    assert_includes messages, "muss groesser als USDC|0.00 sein"
  end

  def test_uses_registered_rate_for_cross_type_threshold_when_available
    Amount.register_default_rate :USD, :USDC, "1"

    assert cross_type_threshold_model.new(amount: "USDC|2.00").valid?
  end

  def test_numeric_thresholds_on_multi_symbol_attribute_accept_value_inside_range
    assert bounded_numeric_threshold_model.new(amount: "USDC|50.00").valid?
  end

  def test_numeric_thresholds_on_multi_symbol_attribute_reject_value_at_exclusive_lower_bound
    refute bounded_numeric_threshold_model.new(amount: "USDC|0.00").valid?
  end

  def test_numeric_thresholds_on_multi_symbol_attribute_report_lower_bound
    holding = bounded_numeric_threshold_model.new(amount: "USDC|0.00")

    assert_includes errors_on(holding, :amount).join, "greater than"
  end

  def test_numeric_thresholds_on_multi_symbol_attribute_reject_value_above_upper_bound
    refute bounded_numeric_threshold_model.new(amount: "USDC|150.00").valid?
  end

  def test_numeric_thresholds_on_multi_symbol_attribute_report_upper_bound
    holding = bounded_numeric_threshold_model.new(amount: "USDC|150.00")

    assert_includes errors_on(holding, :amount).join, "less than"
  end

  # The same `greater_than: 1` is interpreted as 1 USDC for a USDC value and
  # as 1 SOL for a SOL value, because the threshold inherits the value's
  # symbol on multi-symbol attributes.
  def test_numeric_threshold_accepts_usdc_value_above_one_usdc
    assert greater_than_one_model.new(amount: "USDC|2.00").valid?
  end

  def test_numeric_threshold_rejects_usdc_value_below_one_usdc
    refute greater_than_one_model.new(amount: "USDC|0.50").valid?
  end

  def test_numeric_threshold_accepts_sol_value_above_one_sol
    assert greater_than_one_model.new(amount: "SOL|2").valid?
  end

  def test_numeric_threshold_rejects_sol_value_below_one_sol
    refute greater_than_one_model.new(amount: "SOL|0.5").valid?
  end

  private

  def validated(**attributes)
    ValidatedHolding.new(reserve: "USDC|1.25", **attributes)
  end

  def errors_on(record, attribute)
    record.valid?
    record.errors[attribute]
  end

  def holdings_model_validating_amount(**options)
    Class.new(::ActiveRecord::Base) do
      self.table_name = "holdings"

      has_amount :amount
      validates :amount, amount: options
    end
  end

  def cross_type_threshold_model
    holdings_model_validating_amount(greater_than: "USD|1.00")
  end

  def bounded_numeric_threshold_model
    holdings_model_validating_amount(greater_than: 0, less_than_or_equal_to: 100)
  end

  def greater_than_one_model
    holdings_model_validating_amount(greater_than: 1)
  end

  # Runs the block under :de with app-provided translations of the
  # validator's error keys.
  def with_german_messages(&)
    original_locales = I18n.available_locales
    I18n.available_locales = original_locales | [:de]
    # rubocop:disable Style/FormatStringToken
    I18n.backend.store_translations(:de, errors: { messages: {
                                      amount_symbol: "muss das Symbol %{expected} haben",
                                      greater_than: "muss groesser als %{count} sein"
                                    } })
    # rubocop:enable Style/FormatStringToken
    I18n.with_locale(:de, &)
  ensure
    I18n.available_locales = original_locales
  end
end
