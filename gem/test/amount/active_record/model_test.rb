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

  private

  def wrong_symbol_fee_holding
    Holding.new.tap { |holding| holding.fee = Amount.new("1", :USDC) }
  end

  def raw_numeric_amount_holding
    Holding.new.tap { |holding| holding.amount = 5 }
  end
end
