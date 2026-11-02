# frozen_string_literal: true

require_relative "../../../support/active_record"

RSpec.describe Amount::ActiveRecord::RSpec::Matchers do
  describe "have_amount_column" do
    let(:holding) { RSpecHolding.create!(amount: "USDC|1.50", fee: 0.25) }

    it "matches a multi-symbol column" do
      expect(holding).to have_amount_column(:amount, "USDC|1.50")
    end

    it "matches a fixed-symbol column" do
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
