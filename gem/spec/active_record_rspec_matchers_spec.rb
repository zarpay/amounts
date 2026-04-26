# frozen_string_literal: true

require "active_record"
require "sqlite3"
require_relative "../lib/amount/active_record"
require_relative "../lib/amount/active_record/rspec"
require_relative "../test/support/amount_test_support"

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

RSpec.describe "ActiveRecord amount matchers" do
  describe "have_amount_column" do
    it "matches both virtual and physical columns" do
      holding = RSpecHolding.create!(amount: "USDC|1.50", fee: 0.25)

      expect(holding).to have_amount_column(:amount, "USDC|1.50")
      expect(holding).to have_amount_column(:fee, Amount.new("0.25", :SOL))
    end

    it "fails with a helpful message" do
      holding = RSpecHolding.create!(amount: "USDC|1.50")

      expect do
        expect(holding).to have_amount_column(:amount, "USDC|2.50")
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /have amount column matching/)
    end
  end

  describe "match_amounts" do
    it "matches grouped amount sums" do
      RSpecHolding.create!(amount: "USDC|10.50")
      RSpecHolding.create!(amount: "USDC|1.00")
      RSpecHolding.create!(amount: "SOL|12.5")

      expect(RSpecHolding.group(:amount_symbol).sum(:amount_atomic)).to match_amounts(USDC: "11.50", SOL: "12.5")
    end

    it "fails with a useful diff-style message" do
      RSpecHolding.create!(amount: "USDC|10.50")

      expect do
        expect(RSpecHolding.group(:amount_symbol).sum(:amount_atomic)).to match_amounts(USDC: "9.50")
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /grouped amounts/)
    end
  end
end
