# frozen_string_literal: true

require "active_record"
require "sqlite3"
require_relative "amount_test_support"
require_relative "../../lib/amount/active_record"

# In-memory SQLite schema and models shared by the ActiveRecord adapter tests.
# Loaded once per process however many test files require it.

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

# Empty tables and the ActiveRecord test types before each test; an empty
# registry after it.
module ActiveRecordTestSetup
  def setup
    Holding.delete_all
    ValidatedHolding.delete_all

    AmountTestSupport.register_active_record_types!
  end

  def teardown
    Amount.registry.clear!
  end
end
