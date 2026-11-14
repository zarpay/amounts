# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordPersistenceTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_amount_column_values_replaces_multi_symbol_amount_with_its_columns
    assert_equal({ "amount_atomic" => 1_500_000, "amount_symbol" => "USDC" },
                 Holding.amount_column_values("amount" => "USDC|1.5"))
  end

  def test_amount_column_values_replaces_fixed_symbol_amount_with_its_column
    assert_equal({ "fee_atomic" => 250_000_000 }, Holding.amount_column_values("fee" => "SOL|0.25"))
  end

  def test_amount_column_values_accepts_symbol_keys
    assert_equal({ "fee_atomic" => 250_000_000 }, Holding.amount_column_values(fee: "SOL|0.25"))
  end

  def test_amount_column_values_casts_numeric_for_fixed_symbol
    assert_equal({ "fee_atomic" => 250_000_000 }, Holding.amount_column_values("fee" => 0.25))
  end

  def test_amount_column_values_accepts_an_amount
    assert_equal({ "fee_atomic" => 250_000_000 }, Holding.amount_column_values("fee" => Amount.new("0.25", :SOL)))
  end

  def test_amount_column_values_passes_other_keys_through
    assert_equal({ "fee_atomic" => 250_000_000, :parent_id => 7 },
                 Holding.amount_column_values("fee" => 0.25, :parent_id => 7))
  end

  def test_amount_column_values_keeps_every_column_of_nil_amount
    assert_equal({ "amount_atomic" => nil, "amount_symbol" => nil }, Holding.amount_column_values("amount" => nil))
  end

  def test_amount_column_values_raises_for_wrong_fixed_symbol
    assert_raises(Amount::TypeMismatch) { Holding.amount_column_values("fee" => "USDC|1") }
  end

  def test_amount_column_values_of_inherited_amount
    assert_equal({ "fee_atomic" => 250_000_000 }, SubHolding.amount_column_values("fee" => 0.25))
  end

  def test_amount_column_values_rows_insert_with_insert_all
    Holding.insert_all([Holding.amount_column_values("amount" => "USDC|1.5"),
                        Holding.amount_column_values("amount" => nil)])

    assert_equal [Amount.new("1.5", :USDC), nil], Holding.order(:id).map(&:amount)
  end
end
