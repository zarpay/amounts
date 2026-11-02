# frozen_string_literal: true

require "active_record"
require "sqlite3"
require_relative "../../lib/amount/active_record"
require_relative "../../lib/amount/active_record/rspec"
require_relative "../../test/support/amount_test_support"

# In-memory SQLite schema and model for the ActiveRecord matcher specs.

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :holdings, force: true do |t|
    t.amount :amount, null: true
    t.amount :fee, symbol: :SOL, null: true
  end
end

class RSpecHolding < ActiveRecord::Base
  self.table_name = "holdings"

  has_amount :amount
  has_amount :fee, symbol: :SOL
end

RSpec.configure do |config|
  config.before(:context) do
    AmountTestSupport.register_active_record_types!
  end

  config.before do
    AmountTestSupport.register_active_record_types!
    RSpecHolding.delete_all
  end

  config.after do
    Amount.registry.clear!
  end
end
