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

  # Several attributes in one query

  def test_sum_amount_of_several_attributes
    assert_equal({ fee: Amount.new("0.3", :SOL), reserve: Amount.new("5", :USDC) },
                 Holding.sum_amount(:fee, :reserve))
  end

  def test_sum_amount_of_several_attributes_runs_one_query
    assert_equal 1, queries_during { Holding.group(:amount_symbol).sum_amount(:amount, :fee, :reserve) }
  end

  def test_sum_amount_of_several_attributes_keys_by_name_given_as_strings
    assert_equal %i[fee reserve], Holding.sum_amount("fee", "reserve").keys
  end

  def test_sum_amount_of_several_attributes_grouped
    assert_equal(
      {
        nil => { amount: nil, fee: Amount.new(0, :SOL) },
        "USD" => { amount: Amount.new("3", :USD), fee: Amount.new(0, :SOL) },
        "USDC" => { amount: Amount.new("3.5", :USDC), fee: Amount.new("0.3", :SOL) }
      },
      Holding.group(:amount_symbol).sum_amount(:amount, :fee)
    )
  end

  # Rows (USDC, USDC) and (NULL, USDC): amount sums only its own row, reserve
  # adds both.
  def test_sum_amount_of_several_multi_symbol_attributes_combines_rows
    assert_equal({ amount: Amount.new("3.5", :USDC), reserve: Amount.new("3.75", :USDC) },
                 Holding.where(amount_symbol: ["USDC", nil]).sum_amount(:amount, :reserve))
  end

  def test_sum_amount_of_several_attributes_keeps_a_group_without_one_of_them
    assert_equal({ amount: nil, reserve: Amount.new("1.25", :USDC) },
                 Holding.group(:amount_symbol).sum_amount(:amount, :reserve).fetch(nil))
  end

  def test_sum_amount_of_several_attributes_with_mixed_symbols_raises_type_mismatch
    assert_raises(Amount::TypeMismatch) { Holding.sum_amount(:fee, :amount) }
  end

  def test_sum_amount_of_several_attributes_with_mixed_symbols_names_the_attribute
    assert_match(/\Aamount has more than one symbol in scope/,
                 error_from(Amount::TypeMismatch) { Holding.sum_amount(:fee, :amount) }.message)
  end

  def test_sum_amount_of_several_attributes_over_no_rows
    assert_equal({ fee: Amount.new(0, :SOL), amount: nil }, Holding.where(id: nil).sum_amount(:fee, :amount))
  end

  def test_sum_amount_of_several_attributes_on_none
    assert_equal({ fee: Amount.new(0, :SOL), amount: nil }, Holding.none.sum_amount(:fee, :amount))
  end

  def test_sum_amount_of_several_attributes_grouped_on_none_is_empty
    assert_empty Holding.none.group(:amount_symbol).sum_amount(:amount, :fee)
  end

  def test_sum_amount_of_several_attributes_grouped_by_two_columns_keys_by_array
    assert_equal [["USDC", nil], %w[USDC USD], %w[USDC USDC]].to_set,
                 Holding.group(:reserve_symbol, :amount_symbol).sum_amount(:amount, :fee).keys.to_set
  end

  def test_sum_amount_with_a_name_given_twice_raises_argument_error
    assert_raises(ArgumentError) { Holding.sum_amount(:fee, :fee) }
  end

  def test_sum_amount_without_names_raises_argument_error
    assert_raises(ArgumentError) { Holding.sum_amount }
  end

  def test_sum_amount_of_an_unknown_name_raises_key_error
    assert_raises(KeyError) { Holding.sum_amount(:fee, :nope) }
  end

  def test_minimum_amount_of_several_attributes
    assert_equal({ fee: Amount.new("0.1", :SOL), reserve: Amount.new("1.25", :USDC) },
                 Holding.minimum_amount(:fee, :reserve))
  end

  def test_minimum_amount_of_several_multi_symbol_attributes_combines_rows
    assert_equal({ amount: Amount.new("1.5", :USDC), reserve: Amount.new("1.25", :USDC) },
                 Holding.where(amount_symbol: ["USDC", nil]).minimum_amount(:amount, :reserve))
  end

  def test_maximum_amount_of_several_attributes_grouped
    assert_equal({ amount: Amount.new("2", :USDC), fee: Amount.new("0.2", :SOL) },
                 Holding.group(:amount_symbol).maximum_amount(:amount, :fee).fetch("USDC"))
  end

  def test_average_amount_of_several_attributes
    assert_equal({ fee: Amount.new("0.15", :SOL), reserve: Amount.new("1.25", :USDC) },
                 Holding.average_amount(:fee, :reserve))
  end

  def test_average_amount_of_several_multi_symbol_attributes_combines_rows
    assert_equal({ amount: Amount.new("1.75", :USDC), reserve: Amount.new("1.25", :USDC) },
                 Holding.where(amount_symbol: ["USDC", nil]).average_amount(:amount, :reserve))
  end

  def test_average_amount_of_several_attributes_truncates_toward_zero
    holdings_with_atomic_fees(1, 2)

    assert_equal Amount.new(1, :SOL, from: :atomic), Holding.average_amount(:fee, :reserve).fetch(:fee)
  end

  def test_average_amount_of_several_attributes_is_nil_for_one_without_amounts
    assert_equal({ amount: Amount.new("3", :USD), fee: nil },
                 Holding.group(:amount_symbol).average_amount(:amount, :fee).fetch("USD"))
  end

  private

  # How many SQL statements the block runs, schema queries aside.
  def queries_during(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ::ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  def holdings_with_atomic_fees(*atomics)
    Holding.delete_all
    atomics.each { |atomic| Holding.create!(fee: Amount.new(atomic, :SOL, from: :atomic)) }
  end
end
