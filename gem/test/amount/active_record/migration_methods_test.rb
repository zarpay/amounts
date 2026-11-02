# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordMigrationMethodsTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_creates_atomic_column_for_multi_symbol_amount
    assert columns.key?("amount_atomic")
  end

  def test_creates_symbol_column_for_multi_symbol_amount
    assert columns.key?("amount_symbol")
  end

  def test_creates_atomic_column_for_fixed_symbol_amount
    assert columns.key?("fee_atomic")
  end

  def test_creates_no_symbol_column_for_fixed_symbol_amount
    refute columns.key?("fee_symbol")
  end

  def test_atomic_column_precision_defaults_to_seventy_eight
    assert_equal 78, columns.fetch("amount_atomic").precision
  end

  def test_symbol_column_limit_is_ten_characters
    assert_equal 10, columns.fetch("amount_symbol").limit
  end

  def test_atomic_column_uses_given_precision
    assert_equal 40, columns.fetch("reserve_atomic").precision
  end

  def test_default_sets_symbol_column_default
    assert_equal "USDC", columns.fetch("reserve_symbol").default
  end

  def test_schema_declares_default_atomic_column_as_scale_zero_decimal
    assert_includes schema_sql, "\"amount_atomic\" decimal(78,0)"
  end

  def test_schema_declares_atomic_column_with_given_precision_as_scale_zero_decimal
    assert_includes schema_sql, "\"reserve_atomic\" decimal(40,0)"
  end

  private

  def columns
    Holding.columns_hash
  end

  def schema_sql
    ::ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'holdings'
    SQL
  end
end
