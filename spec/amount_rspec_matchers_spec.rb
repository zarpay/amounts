# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "Amount RSpec matchers" do
  describe "eq_amount" do
    it "matches a parse string" do
      expect(Amount.usdc("1.50")).to eq_amount("USDC|1.50")
    end

    it "matches a symbol and UI value pair" do
      expect(Amount.usdc("1.50")).to eq_amount(:USDC, "1.50")
    end

    it "matches another amount instance" do
      expect(Amount.usdc("1.50")).to eq_amount(Amount.usdc("1.50"))
    end

    it "fails with a helpful message" do
      expect do
        expect(Amount.usdc("1.50")).to eq_amount("USDC|2.00")
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /equal amount/)
    end
  end

  describe "be_amount_of" do
    it "matches the amount symbol" do
      expect(Amount.usdc("1.50")).to be_amount_of(:USDC)
    end

    it "fails clearly for non-amount values" do
      expect do
        expect(nil).to be_amount_of(:USDC)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /to be an Amount of USDC/)
    end
  end

  describe "predicate matchers" do
    it "matches zero amounts" do
      expect(Amount.usdc(0, from: :atomic)).to be_zero_amount
    end

    it "matches positive amounts" do
      expect(Amount.usdc("1.50")).to be_positive_amount
    end

    it "matches negative amounts" do
      expect(Amount.usdc("-1.50")).to be_negative_amount
    end
  end

  describe "be_approximately_amount" do
    it "matches within a UI delta" do
      expect(Amount.usdc("1.55")).to be_approximately_amount(:USDC, "1.50", within: "0.10")
    end

    it "matches within an amount delta" do
      expect(Amount.usdc("1.55")).to be_approximately_amount(Amount.usdc("1.50"), within: Amount.usdc("0.10"))
    end

    it "fails with a helpful message" do
      expect do
        expect(Amount.usdc("1.80")).to be_approximately_amount(:USDC, "1.50", within: "0.10")
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /within/)
    end
  end
end
