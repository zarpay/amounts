# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordCalculationsTest < Minitest::Test
  include ActiveRecordTestSetup

  # Two USDC holdings with SOL fees, one USD holding without a fee, and one
  # holding with neither. Every holding's reserve is USDC|1.25.
  def setup
    super
    Holding.create!(amount: "USDC|1.5", fee: "SOL|0.1")
    Holding.create!(amount: "USDC|2", fee: "SOL|0.2")
    Holding.create!(amount: "USD|3")
    Holding.create!
  end

  def test_sum_amount_of_fixed_symbol
    assert_equal Amount.new("0.3", :SOL), Holding.sum_amount(:fee)
  end

  def test_sum_amount_of_fixed_symbol_over_no_rows_is_zero
    assert_equal Amount.new(0, :SOL), Holding.where(id: nil).sum_amount(:fee)
  end

  def test_sum_amount_of_fixed_symbol_on_none_is_zero
    assert_equal Amount.new(0, :SOL), Holding.none.sum_amount(:fee)
  end

  def test_sum_amount_of_multi_symbol_with_one_symbol_in_scope
    assert_equal Amount.new("3.5", :USDC), Holding.amount_in(:USDC).sum_amount(:amount)
  end

  def test_sum_amount_of_multi_symbol_over_no_rows_is_nil
    assert_nil Holding.where(id: nil).sum_amount(:amount)
  end

  def test_sum_amount_with_mixed_symbols_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Holding.sum_amount(:amount) }
  end

  def test_sum_amount_with_mixed_symbols_names_the_symbols
    assert_match(/amount has more than one symbol in scope: USD, USDC/,
                 error_from(Amount::TypeMismatch) { Holding.sum_amount(:amount) }.message)
  end

  def test_sum_amount_grouped_by_symbol_column
    assert_equal({ "USD" => Amount.new("3", :USD), "USDC" => Amount.new("3.5", :USDC) },
                 Holding.group(:amount_symbol).sum_amount(:amount))
  end

  def test_sum_amount_of_fixed_symbol_grouped
    assert_equal({ nil => Amount.new(0, :SOL), "USD" => Amount.new(0, :SOL), "USDC" => Amount.new("0.3", :SOL) },
                 Holding.group(:amount_symbol).sum_amount(:fee))
  end

  def test_sum_amount_grouped_by_two_columns_keys_by_array
    assert_equal({ %w[USDC USD] => Amount.new("3", :USD), %w[USDC USDC] => Amount.new("3.5", :USDC) },
                 Holding.group(:reserve_symbol, :amount_symbol).sum_amount(:amount))
  end

  def test_sum_amount_grouped_by_sql_expression
    assert_equal({ "USD" => Amount.new("3", :USD), "USDC" => Amount.new("3.5", :USDC) },
                 Holding.group("UPPER(amount_symbol)").sum_amount(:amount))
  end

  # `pluck` refuses a raw SQL string like this one unless it's wrapped in
  # `Arel.sql`; Rails' `group(...).sum` accepts it.
  def test_sum_amount_grouped_by_raw_sql_expression
    assert_equal({ "none" => Amount.new(0, :SOL), "USD" => Amount.new(0, :SOL), "USDC" => Amount.new("0.3", :SOL) },
                 Holding.group("COALESCE(amount_symbol, 'none')").sum_amount(:fee))
  end

  def test_sum_amount_grouped_by_arel_node
    assert_equal({ "USD" => Amount.new("3", :USD), "USDC" => Amount.new("3.5", :USDC) },
                 Holding.group(Holding.arel_table[:amount_symbol]).sum_amount(:amount))
  end

  def test_sum_amount_grouped_on_none_is_empty
    assert_empty Holding.none.group(:amount_symbol).sum_amount(:fee)
  end

  def test_sum_amount_with_mixed_symbols_in_one_group_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Holding.group(:reserve_symbol).sum_amount(:amount) }
  end

  def test_sum_amount_grouped_by_association_raises_argument_error
    assert_raises(ArgumentError) { ChildHolding.group(:parent).sum_amount(:fee) }
  end

  def test_sum_amount_grouped_by_association_names_its_foreign_key
    assert_match(/group by parent_id, not the parent association/,
                 error_from(ArgumentError) { ChildHolding.group(:parent).sum_amount(:fee) }.message)
  end

  def test_sum_amount_of_inherited_amount
    assert_equal Amount.new("0.3", :SOL), SubHolding.sum_amount(:fee)
  end

  def test_minimum_amount
    assert_equal Amount.new("0.1", :SOL), Holding.minimum_amount(:fee)
  end

  def test_minimum_amount_over_no_rows_is_nil
    assert_nil Holding.where(id: nil).minimum_amount(:fee)
  end

  def test_minimum_amount_with_mixed_symbols_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Holding.minimum_amount(:amount) }
  end

  def test_maximum_amount
    assert_equal Amount.new("0.2", :SOL), Holding.maximum_amount(:fee)
  end

  def test_maximum_amount_grouped_by_symbol_column
    assert_equal({ "USD" => Amount.new("3", :USD), "USDC" => Amount.new("2", :USDC) },
                 Holding.group(:amount_symbol).maximum_amount(:amount))
  end

  def test_average_amount_counts_only_rows_with_an_amount
    assert_equal Amount.new("0.15", :SOL), Holding.average_amount(:fee)
  end

  def test_average_amount_truncates_toward_zero
    holdings_with_atomic_fees(1, 2)

    assert_equal Amount.new(1, :SOL, from: :atomic), Holding.average_amount(:fee)
  end

  def test_average_amount_of_negative_amounts_truncates_toward_zero
    holdings_with_atomic_fees(-1, -2)

    assert_equal Amount.new(-1, :SOL, from: :atomic), Holding.average_amount(:fee)
  end

  def test_average_amount_over_no_rows_is_nil
    assert_nil Holding.where(id: nil).average_amount(:fee)
  end

  def test_average_amount_grouped_by_symbol_column
    assert_equal({ "USD" => Amount.new("3", :USD), "USDC" => Amount.new("1.75", :USDC) },
                 Holding.group(:amount_symbol).average_amount(:amount))
  end

  def test_average_amount_of_group_without_amounts_is_nil
    assert_nil Holding.group(:amount_symbol).average_amount(:fee).fetch("USD")
  end

  def test_average_amount_with_mixed_symbols_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Holding.average_amount(:amount) }
  end

  def test_rails_average_still_works
    assert_equal BigDecimal("150000000"), Holding.average(:fee_atomic)
  end

  private

  def holdings_with_atomic_fees(*atomics)
    Holding.delete_all
    atomics.each { |atomic| Holding.create!(fee: Amount.new(atomic, :SOL, from: :atomic)) }
  end
end
