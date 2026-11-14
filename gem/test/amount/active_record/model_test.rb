# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordModelTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_fixed_symbol_writer_with_wrong_symbol_makes_record_invalid
    refute wrong_symbol_fee_holding.valid?
  end

  def test_fixed_symbol_writer_with_wrong_symbol_reports_error_on_validation
    holding = wrong_symbol_fee_holding
    holding.valid?

    assert_includes holding.errors[:fee], "expected SOL, got USDC"
  end

  def test_multi_symbol_writer_with_raw_numeric_makes_record_invalid
    refute raw_numeric_amount_holding.valid?
  end

  def test_multi_symbol_writer_with_raw_numeric_reports_error_on_validation
    holding = raw_numeric_amount_holding
    holding.valid?

    assert_includes holding.errors[:amount], "raw numeric assignment requires a fixed symbol"
  end

  def test_subclass_inherits_amount_attribute_definitions
    assert_equal %i[amount fee reserve], SubHolding.amount_attribute_definitions.keys
  end

  def test_subclass_resolves_inherited_atomic_column
    assert_equal "fee_atomic", SubHolding.amount_atomic_column(:fee)
  end

  def test_subclass_resolves_inherited_component_columns
    assert_equal %w[amount_atomic amount_symbol], SubHolding.amount_component_columns(:amount)
  end

  def test_subclass_adds_its_own_amount
    assert_equal %i[amount fee reserve bonus], BonusHolding.amount_attribute_definitions.keys
  end

  def test_subclass_amount_does_not_reach_parent
    refute_includes Holding.amount_attribute_definitions.keys, :bonus
  end

  def test_subclass_amount_does_not_reach_sibling
    refute_includes SubHolding.amount_attribute_definitions.keys, :bonus
  end

  def test_model_without_amounts_has_no_definitions
    assert_empty ::ActiveRecord::Base.amount_attribute_definitions
  end

  def test_definitions_are_not_readable_from_a_record
    refute_respond_to Holding.new, :amount_attribute_definitions
  end

  private

  def wrong_symbol_fee_holding
    Holding.new.tap { |holding| holding.fee = Amount.new("1", :USDC) }
  end

  def raw_numeric_amount_holding
    Holding.new.tap { |holding| holding.amount = 5 }
  end
end
