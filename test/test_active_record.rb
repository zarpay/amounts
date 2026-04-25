# frozen_string_literal: true

require_relative "test_helper"
require "active_record"
require "sqlite3"
require_relative "../lib/amount/active_record"

AmountTestSupport.register_active_record_types!

::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

::ActiveRecord::Schema.define do
  create_table :holdings, force: true do |t|
    t.amount :amount, null: true
    t.amount :fee, symbol: :SOL, null: true
    t.amount :reserve, precision: 40, default: "USDC|1.25", null: false
  end
end

class Holding < ::ActiveRecord::Base
  has_amount :amount
  has_amount :fee, symbol: :SOL
  has_amount :reserve
end

class ValidatedHolding < ::ActiveRecord::Base
  self.table_name = "holdings"

  has_amount :amount
  has_amount :fee, symbol: :SOL
  has_amount :reserve

  validates :amount, amount: {
    symbol: :USDC,
    greater_than: "USDC|0",
    less_than_or_equal_to: "USDC|1000"
  }
  validates :fee, amount: {
    symbol: :SOL,
    greater_than: 0,
    less_than: 10,
    allow_nil: true
  }
  validates :reserve, amount: {
    greater_than_or_equal_to: "USDC|1.25"
  }
end

class AmountActiveRecordTest < Minitest::Test
  def setup
    Holding.delete_all
    ValidatedHolding.delete_all

    AmountTestSupport.register_active_record_types!
  end

  def teardown
    Amount.registry.clear!
  end

  def test_migration_dsl_creates_expected_columns
    columns = Holding.columns_hash
    schema_sql = ::ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'holdings'
    SQL

    assert columns.key?("amount_atomic")
    assert columns.key?("amount_symbol")
    assert columns.key?("fee_atomic")
    refute columns.key?("fee_symbol")
    assert_equal 78, columns.fetch("amount_atomic").precision
    assert_equal 10, columns.fetch("amount_symbol").limit
    assert_equal 40, columns.fetch("reserve_atomic").precision
    assert_equal "USDC", columns.fetch("reserve_symbol").default
    assert_includes schema_sql, "\"amount_atomic\" decimal(78,0)"
    assert_includes schema_sql, "\"reserve_atomic\" decimal(40,0)"
  end

  def test_reader_returns_amount
    holding = Holding.create!(amount_atomic: 1_500_000, amount_symbol: "USDC")

    assert_equal Amount.new("1.5", :USDC), holding.amount
  end

  def test_reader_returns_nil_when_atomic_is_nil
    holding = Holding.create!

    assert_nil holding.amount
    assert_nil holding.fee
  end

  def test_multi_symbol_writer_accepts_amount_string_and_hash
    holding = Holding.new
    holding.amount = Amount.new("1.5", :USDC)
    assert_equal 1_500_000, holding.amount_atomic
    assert_equal "USDC", holding.amount_symbol

    holding.amount = "USD|2.50"
    assert_equal 250, holding.amount_atomic
    assert_equal "USD", holding.amount_symbol

    holding.amount = { "atomic" => 42, "symbol" => "USDC" }
    assert_equal Amount.new(42, :USDC, from: :atomic), holding.amount
  end

  def test_fixed_symbol_writer_accepts_amount_and_raw_numeric
    holding = Holding.new
    holding.fee = 1.25

    assert_equal 1_250_000_000, holding.fee_atomic
    assert_equal Amount.new("1.25", :SOL), holding.fee

    holding.fee = Amount.new("2.5", :SOL)
    assert_equal 2_500_000_000, holding.fee_atomic
  end

  def test_fixed_symbol_writer_rejects_wrong_symbol_cleanly
    holding = Holding.new
    holding.fee = Amount.new("1", :USDC)

    refute holding.valid?
    assert_includes holding.errors[:fee], "expected SOL, got USDC"
  end

  def test_multi_symbol_writer_rejects_invalid_input_cleanly
    holding = Holding.new
    holding.amount = 5

    refute holding.valid?
    assert_includes holding.errors[:amount], "raw numeric assignment requires a fixed symbol"
  end

  def test_scope_matches_atomic_and_symbol
    usdc = Holding.create!(amount: Amount.new("1.5", :USDC))
    Holding.create!(amount: Amount.new("1.5", :USD))

    assert_equal [usdc.id], Holding.where_amount("USDC|1.5").pluck(:id)
    assert_equal [usdc.id], Holding.amount_in(:USDC).pluck(:id)
  end

  def test_comparison_scopes_filter_multi_symbol_amounts_by_symbol_and_atomic_value
    low = Holding.create!(amount: "USDC|1.00")
    mid = Holding.create!(amount: "USDC|2.00")
    high = Holding.create!(amount: "USDC|3.00")
    Holding.create!(amount: "USD|2.50")

    assert_equal [mid.id, high.id], Holding.where_amount_gt("USDC|1.50").pluck(:id)
    assert_equal [mid.id, high.id], Holding.where_amount_gte("USDC|2.00").pluck(:id)
    assert_equal [low.id, mid.id], Holding.where_amount_lt("USDC|2.50").pluck(:id)
    assert_equal [low.id, mid.id], Holding.where_amount_lte("USDC|2.00").pluck(:id)
  end

  def test_between_scope_filters_multi_symbol_amounts_with_inclusive_bounds
    low = Holding.create!(amount: "USDC|1.00")
    mid = Holding.create!(amount: "USDC|2.00")
    high = Holding.create!(amount: "USDC|3.00")
    Holding.create!(amount: "USD|2.00")

    assert_equal [low.id, mid.id, high.id], Holding.where_amount_between("USDC|1.00", "USDC|3.00").pluck(:id)
    assert_equal [mid.id], Holding.where_amount_between("USDC|1.50", "USDC|2.50").pluck(:id)
  end

  def test_between_scope_requires_matching_symbols_for_multi_symbol_amounts
    assert_raises(Amount::TypeMismatch) do
      Holding.where_amount_between("USDC|1.00", "USD|2.00").load
    end
  end

  def test_comparison_scopes_support_fixed_symbol_numeric_values
    low = Holding.create!(fee: 0.25)
    mid = Holding.create!(fee: 0.50)
    high = Holding.create!(fee: 0.75)

    assert_equal [mid.id, high.id], Holding.where_fee_gt(0.25).pluck(:id)
    assert_equal [mid.id, high.id], Holding.where_fee_gte(0.50).pluck(:id)
    assert_equal [low.id, mid.id], Holding.where_fee_lt(0.75).pluck(:id)
    assert_equal [low.id, mid.id], Holding.where_fee_lte(0.50).pluck(:id)
    assert_equal [mid.id], Holding.where_fee_between(0.30, 0.60).pluck(:id)
  end

  def test_dirty_tracking_uses_virtual_amount_attribute
    holding = Holding.create!(amount: Amount.new("1.0", :USDC))
    holding.amount = "USDC|2.5"

    assert holding.amount_changed?
    assert_equal [Amount.new("1.0", :USDC), Amount.new("2.5", :USDC)], holding.amount_change

    holding.save!

    assert holding.saved_change_to_amount?
    assert_equal Amount.new("1.0", :USDC), holding.amount_before_last_save
    assert_equal [Amount.new("1.0", :USDC), Amount.new("2.5", :USDC)], holding.saved_change_to_amount
  end

  def test_validation_requires_both_amount_columns_or_neither
    holding = Holding.new(amount_atomic: 100)

    refute holding.valid?
    assert_includes holding.errors[:amount], "must set both atomic and symbol or neither"
  end

  def test_nil_assignment_clears_both_columns
    holding = Holding.create!(amount: Amount.new("1", :USDC))
    holding.amount = nil

    assert_nil holding.amount_atomic
    assert_nil holding.amount_symbol
    assert_nil holding.amount
  end

  def test_group_sum_works_on_atomic_and_symbol_columns
    Holding.create!(amount: Amount.new("1.5", :USDC))
    Holding.create!(amount: Amount.new("2.0", :USDC))
    Holding.create!(amount: Amount.new("3.0", :USD))

    sums = Holding.group(:amount_symbol).sum(:amount_atomic)

    assert_equal 3_500_000, sums["USDC"]
    assert_equal 300, sums["USD"]
  end

  def test_large_atomic_value_round_trips_through_sqlite
    skip "SQLite stores DECIMAL(78,0) values above 64-bit range imprecisely under ActiveRecord"

    huge_atomic = 10**30
    holding = Holding.create!(amount: Amount.new(huge_atomic, :SOL, from: :atomic))

    assert_equal huge_atomic, holding.reload.amount.atomic
  end

  def test_amount_validator_accepts_valid_multi_symbol_amount
    holding = ValidatedHolding.new(amount: "USDC|100.00", reserve: "USDC|1.25")

    assert holding.valid?
  end

  def test_amount_validator_rejects_wrong_symbol
    holding = ValidatedHolding.new(amount: "USD|100.00", reserve: "USDC|1.25")

    refute holding.valid?
    assert_includes holding.errors[:amount], "must have symbol USDC"
  end

  def test_amount_validator_rejects_amount_below_lower_bound
    holding = ValidatedHolding.new(amount: "USDC|0.00", reserve: "USDC|1.25")

    refute holding.valid?
    assert_includes holding.errors[:amount], "must be greater than USDC|0.0"
  end

  def test_amount_validator_rejects_amount_above_upper_bound
    holding = ValidatedHolding.new(amount: "USDC|1000.01", reserve: "USDC|1.25")

    refute holding.valid?
    assert_includes holding.errors[:amount], "must be less than or equal to USDC|1000.0"
  end

  def test_amount_validator_allows_nil_when_allow_nil_is_set
    holding = ValidatedHolding.new(amount: "USDC|100.00", reserve: "USDC|1.25", fee: nil)

    assert holding.valid?
  end

  def test_amount_validator_supports_fixed_symbol_numeric_thresholds
    holding = ValidatedHolding.new(amount: "USDC|100.00", reserve: "USDC|1.25", fee: 0.5)

    assert holding.valid?
  end

  def test_amount_validator_rejects_fixed_symbol_amount_below_lower_bound
    holding = ValidatedHolding.new(amount: "USDC|100.00", reserve: "USDC|1.25", fee: 0)

    refute holding.valid?
    assert_includes holding.errors[:fee], "must be greater than SOL|0.0"
  end

  def test_amount_validator_rejects_fixed_symbol_amount_at_exclusive_upper_bound
    holding = ValidatedHolding.new(amount: "USDC|100.00", reserve: "USDC|1.25", fee: 10)

    refute holding.valid?
    assert_includes holding.errors[:fee], "must be less than SOL|10.0"
  end

  def test_amount_validator_rejects_cross_type_threshold_without_rate
    klass = Class.new(::ActiveRecord::Base) do
      self.table_name = "holdings"

      has_amount :amount
      validates :amount, amount: { greater_than: "USD|1.00" }
    end

    holding = klass.new(amount: "USDC|2.00")

    refute holding.valid?
    assert_includes holding.errors[:amount], "cannot compare USDC to USD for greater_than"
  end

  def test_amount_validator_uses_registered_rate_for_cross_type_threshold_when_available
    Amount.register_default_rate :USD, :USDC, "1"

    klass = Class.new(::ActiveRecord::Base) do
      self.table_name = "holdings"

      has_amount :amount
      validates :amount, amount: { greater_than: "USD|1.00" }
    end

    holding = klass.new(amount: "USDC|2.00")

    assert holding.valid?
  end

  def test_custom_class_symbol_round_trips_through_active_record
    metal_class = Class.new(Amount) do
      def self.name
        "MetalAmount"
      end
    end
    Amount.register :METAL, decimals: 4, class: metal_class

    ::ActiveRecord::Schema.define do
      create_table :metal_holdings, force: true do |t|
        t.amount :weight, symbol: :METAL, null: false
      end
    end

    klass = Class.new(::ActiveRecord::Base) do
      self.table_name = "metal_holdings"
      has_amount :weight, symbol: :METAL
    end

    record = klass.create!(weight: metal_class.new("2.5", :METAL))
    record.reload

    assert_instance_of metal_class, record.weight
    assert_equal 25_000, record.weight.atomic
  end
end
