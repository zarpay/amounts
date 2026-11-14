# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordDirtyTest < Minitest::Test
  include ActiveRecordTestSetup

  def setup
    super
    @holding = Holding.create!(amount: "USDC|10.06", fee: "SOL|0.5")
  end

  def test_amount_changes_keys_a_changed_amount_by_name
    @holding.amount = "USD|3"

    assert_equal({ "amount" => [Amount.new("10.06", :USDC), Amount.new("3", :USD)] }, @holding.amount_changes)
  end

  def test_amount_changes_reports_a_cleared_amount
    @holding.fee = nil

    assert_equal({ "fee" => [Amount.new("0.5", :SOL), nil] }, @holding.amount_changes)
  end

  def test_amount_changes_keeps_other_attribute_changes
    @holding.parent_id = 7

    assert_equal({ "parent_id" => [nil, 7] }, @holding.amount_changes)
  end

  def test_amount_changes_of_unchanged_record_is_empty
    assert_empty @holding.amount_changes
  end

  def test_amount_changes_reads_with_symbol_keys
    @holding.amount = "USD|3"

    assert_equal [Amount.new("10.06", :USDC), Amount.new("3", :USD)], @holding.amount_changes[:amount]
  end

  def test_saved_amount_changes_keys_a_saved_amount_by_name
    @holding.update!(fee: "SOL|0.75")

    assert_equal({ "fee" => [Amount.new("0.5", :SOL), Amount.new("0.75", :SOL)] }, @holding.saved_amount_changes)
  end

  def test_saved_amount_changes_of_created_record
    assert_equal [nil, Amount.new("10.06", :USDC)], @holding.saved_amount_changes["amount"]
  end

  def test_changes_stay_keyed_by_column
    @holding.amount = "USD|3"

    assert_equal %w[amount_atomic amount_symbol], @holding.changes.keys
  end

  def test_saved_changes_stay_keyed_by_column
    @holding.update!(fee: "SOL|0.75")

    assert_equal %w[fee_atomic], @holding.saved_changes.keys
  end

  def test_saved_amount_changes_of_inherited_amount
    sub = SubHolding.find(@holding.id)
    sub.update!(fee: "SOL|0.75")

    assert_equal [Amount.new("0.5", :SOL), Amount.new("0.75", :SOL)], sub.saved_amount_changes["fee"]
  end
end
