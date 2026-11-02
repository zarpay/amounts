# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordAttributeDefinitionTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_reader_returns_amount
    holding = Holding.create!(amount_atomic: 1_500_000, amount_symbol: "USDC")

    assert_equal Amount.new("1.5", :USDC), holding.amount
  end

  def test_multi_symbol_reader_returns_nil_when_atomic_is_nil
    assert_nil Holding.create!.amount
  end

  def test_fixed_symbol_reader_returns_nil_when_atomic_is_nil
    assert_nil Holding.create!.fee
  end

  def test_multi_symbol_writer_stores_amount_atomic
    assert_equal 1_500_000, amount_written_holding.amount_atomic
  end

  def test_multi_symbol_writer_stores_amount_symbol
    assert_equal "USDC", amount_written_holding.amount_symbol
  end

  def test_fixed_symbol_writer_stores_amount_atomic
    holding = Holding.new
    holding.fee = Amount.new("2.5", :SOL)

    assert_equal 2_500_000_000, holding.fee_atomic
  end

  def test_nil_assignment_clears_atomic_column
    assert_nil nil_assigned_holding.amount_atomic
  end

  def test_nil_assignment_clears_symbol_column
    assert_nil nil_assigned_holding.amount_symbol
  end

  def test_nil_assignment_reads_back_nil
    assert_nil nil_assigned_holding.amount
  end

  def test_where_scope_matches_atomic_and_symbol
    usdc = create_same_value_in_two_symbols

    assert_equal [usdc.id], Holding.where_amount("USDC|1.5").pluck(:id)
  end

  def test_in_scope_matches_symbol
    usdc = create_same_value_in_two_symbols

    assert_equal [usdc.id], Holding.amount_in(:USDC).pluck(:id)
  end

  def test_gt_scope_filters_multi_symbol_amounts_by_symbol_and_atomic_value
    _low, mid, high = create_usdc_ladder

    assert_equal [mid.id, high.id], Holding.where_amount_gt("USDC|1.50").pluck(:id)
  end

  def test_gte_scope_filters_multi_symbol_amounts_by_symbol_and_atomic_value
    _low, mid, high = create_usdc_ladder

    assert_equal [mid.id, high.id], Holding.where_amount_gte("USDC|2.00").pluck(:id)
  end

  def test_lt_scope_filters_multi_symbol_amounts_by_symbol_and_atomic_value
    low, mid, _high = create_usdc_ladder

    assert_equal [low.id, mid.id], Holding.where_amount_lt("USDC|2.50").pluck(:id)
  end

  def test_lte_scope_filters_multi_symbol_amounts_by_symbol_and_atomic_value
    low, mid, _high = create_usdc_ladder

    assert_equal [low.id, mid.id], Holding.where_amount_lte("USDC|2.00").pluck(:id)
  end

  def test_between_scope_includes_both_bounds_for_multi_symbol_amounts
    low, mid, high = create_usdc_ladder(other: "USD|2.00")

    assert_equal [low.id, mid.id, high.id], Holding.where_amount_between("USDC|1.00", "USDC|3.00").pluck(:id)
  end

  def test_between_scope_filters_multi_symbol_amounts_inside_bounds
    _low, mid, _high = create_usdc_ladder(other: "USD|2.00")

    assert_equal [mid.id], Holding.where_amount_between("USDC|1.50", "USDC|2.50").pluck(:id)
  end

  def test_between_scope_requires_matching_symbols_for_multi_symbol_amounts
    assert_raises(Amount::TypeMismatch) do
      Holding.where_amount_between("USDC|1.00", "USD|2.00").load
    end
  end

  def test_gt_scope_supports_fixed_symbol_numeric_values
    _low, mid, high = create_fee_ladder

    assert_equal [mid.id, high.id], Holding.where_fee_gt(0.25).pluck(:id)
  end

  def test_gte_scope_supports_fixed_symbol_numeric_values
    _low, mid, high = create_fee_ladder

    assert_equal [mid.id, high.id], Holding.where_fee_gte(0.50).pluck(:id)
  end

  def test_lt_scope_supports_fixed_symbol_numeric_values
    low, mid, _high = create_fee_ladder

    assert_equal [low.id, mid.id], Holding.where_fee_lt(0.75).pluck(:id)
  end

  def test_lte_scope_supports_fixed_symbol_numeric_values
    low, mid, _high = create_fee_ladder

    assert_equal [low.id, mid.id], Holding.where_fee_lte(0.50).pluck(:id)
  end

  def test_between_scope_supports_fixed_symbol_numeric_values
    _low, mid, _high = create_fee_ladder

    assert_equal [mid.id], Holding.where_fee_between(0.30, 0.60).pluck(:id)
  end

  def test_changed_predicate_uses_virtual_amount_attribute
    assert changed_holding.amount_changed?
  end

  def test_change_uses_virtual_amount_attribute
    assert_equal [Amount.new("1.0", :USDC), Amount.new("2.5", :USDC)], changed_holding.amount_change
  end

  def test_saved_change_predicate_uses_virtual_amount_attribute
    assert saved_holding.saved_change_to_amount?
  end

  def test_before_last_save_uses_virtual_amount_attribute
    assert_equal Amount.new("1.0", :USDC), saved_holding.amount_before_last_save
  end

  def test_saved_change_uses_virtual_amount_attribute
    assert_equal [Amount.new("1.0", :USDC), Amount.new("2.5", :USDC)], saved_holding.saved_change_to_amount
  end

  def test_validation_rejects_atomic_without_symbol
    refute Holding.new(amount_atomic: 100).valid?
  end

  def test_validation_requires_both_amount_columns_or_neither
    holding = Holding.new(amount_atomic: 100)
    holding.valid?

    assert_includes holding.errors[:amount], "must set both atomic and symbol or neither"
  end

  def test_group_sum_totals_first_symbol_atomic_column
    assert_equal 3_500_000, grouped_sums["USDC"]
  end

  def test_group_sum_totals_second_symbol_atomic_column
    assert_equal 300, grouped_sums["USD"]
  end

  private

  def amount_written_holding
    Holding.new.tap { |holding| holding.amount = Amount.new("1.5", :USDC) }
  end

  def nil_assigned_holding
    holding = Holding.create!(amount: Amount.new("1", :USDC))
    holding.amount = nil
    holding
  end

  # The USDC record; a USD record with the same value is created alongside.
  def create_same_value_in_two_symbols
    usdc = Holding.create!(amount: Amount.new("1.5", :USDC))
    Holding.create!(amount: Amount.new("1.5", :USD))
    usdc
  end

  # USDC 1.00, 2.00 and 3.00 (returned), plus one record in another symbol.
  def create_usdc_ladder(other: "USD|2.50")
    ladder = ["USDC|1.00", "USDC|2.00", "USDC|3.00"].map { |amount| Holding.create!(amount:) }
    Holding.create!(amount: other)
    ladder
  end

  def create_fee_ladder
    [0.25, 0.50, 0.75].map { |fee| Holding.create!(fee:) }
  end

  def changed_holding
    holding = Holding.create!(amount: Amount.new("1.0", :USDC))
    holding.amount = "USDC|2.5"
    holding
  end

  def saved_holding
    changed_holding.tap(&:save!)
  end

  def grouped_sums
    Holding.create!(amount: Amount.new("1.5", :USDC))
    Holding.create!(amount: Amount.new("2.0", :USDC))
    Holding.create!(amount: Amount.new("3.0", :USD))

    Holding.group(:amount_symbol).sum(:amount_atomic)
  end
end
