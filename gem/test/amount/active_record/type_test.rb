# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/active_record_test_support"

class AmountActiveRecordTypeTest < Minitest::Test
  include ActiveRecordTestSetup

  def test_multi_symbol_writer_parses_string_into_atomic_column
    assert_equal 250, holding_with(amount: "USD|2.50").amount_atomic
  end

  def test_multi_symbol_writer_parses_string_into_symbol_column
    assert_equal "USD", holding_with(amount: "USD|2.50").amount_symbol
  end

  def test_multi_symbol_writer_loads_atomic_hash
    holding = holding_with(amount: { "atomic" => 42, "symbol" => "USDC" })

    assert_equal Amount.new(42, :USDC, from: :atomic), holding.amount
  end

  def test_fixed_symbol_writer_converts_raw_float_into_atomic_column
    assert_equal 1_250_000_000, holding_with(fee: 1.25).fee_atomic
  end

  def test_fixed_symbol_writer_reads_back_raw_float_as_amount
    assert_equal Amount.new("1.25", :SOL), holding_with(fee: 1.25).fee
  end

  def test_large_atomic_value_round_trips_through_sqlite
    skip "SQLite stores DECIMAL(78,0) values above 64-bit range imprecisely under ActiveRecord"

    huge_atomic = 10**30
    holding = Holding.create!(amount: Amount.new(huge_atomic, :SOL, from: :atomic))

    assert_equal huge_atomic, holding.reload.amount.atomic
  end

  def test_custom_class_symbol_reads_back_as_registered_class
    assert_instance_of metal_class, metal_record.weight
  end

  def test_custom_class_symbol_reads_back_atomic_value
    assert_equal 25_000, metal_record.weight.atomic
  end

  private

  def holding_with(**attributes)
    holding = Holding.new
    attributes.each { |name, value| holding.public_send("#{name}=", value) }
    holding
  end

  def metal_class
    @metal_class ||= Class.new(Amount) do
      def self.name
        "MetalAmount"
      end
    end
  end

  def metal_record
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

    klass.create!(weight: metal_class.new("2.5", :METAL)).reload
  end
end
