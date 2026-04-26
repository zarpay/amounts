require "rails_helper"

# =============================================================================
# Amount::ActiveRecord::Type spec — direct coverage of the cast/dump utility
# =============================================================================
#
# `Type` is the public class that `has_amount` uses internally to translate
# between the values a Ruby caller assigns and the {atomic, symbol} pair
# the database stores.
#
# Most tests in the harness exercise Type indirectly through model writers
# and readers, but some failure modes are easier to verify when called
# directly:
#
#   Type.new                    multi-symbol instance (no fixed binding)
#   Type.new(symbol: :SOL)      fixed-symbol instance
#
#   #cast(value)                input -> Amount or nil. The most input-
#                               polymorphic surface in the gem; this spec
#                               covers Amount instance, compact string,
#                               {atomic:,symbol:} and {value:,symbol:}
#                               hashes (both key conventions), raw numerics
#                               (only for fixed-symbol), nil/empty-string
#                               clearing, hash with no recognized keys,
#                               unsupported classes
#
#   #deserialize(atomic, sym)   atomic + symbol -> Amount, used on every
#                               read from a has_amount column
#
#   #dump(value)                Amount -> {atomic:, symbol:} for the rare
#                               caller that needs to write through Type
#                               directly
RSpec.describe Amount::ActiveRecord::Type, :aggregate_failures do
  describe "multi-symbol Type (no fixed_symbol)" do
    subject(:type) { described_class.new }

    it "exposes a nil fixed_symbol" do
      expect(type.fixed_symbol).to be_nil
    end

    describe "#cast" do
      it "returns nil for nil and empty string" do
        expect(type.cast(nil)).to be_nil
        expect(type.cast("")).to be_nil
      end

      it "passes Amount instances through unchanged" do
        amount = Amount.usdc("1")
        expect(type.cast(amount)).to be(amount)
      end

      it "parses compact strings" do
        expect(type.cast("USDC|1.50")).to eq_amount("USDC|1.5")
      end

      it "loads {atomic:, symbol:} hashes (symbol keys)" do
        expect(type.cast(atomic: 1_500_000, symbol: :USDC)).to eq_amount("USDC|1.5")
      end

      it "loads {atomic:, symbol:} hashes (string keys)" do
        expect(type.cast("atomic" => 1_500_000, "symbol" => "USDC")).to eq_amount("USDC|1.5")
      end

      it "builds {value:, symbol:} hashes" do
        expect(type.cast(value: "1.5", symbol: :USDC)).to eq_amount("USDC|1.5")
      end

      it "raises InvalidInput for hashes missing both atomic and value" do
        expect { type.cast({ unrelated: "key" }) }.to raise_error(Amount::InvalidInput, /atomic\/symbol or value\/symbol/)
      end

      it "raises InvalidInput for raw numerics on multi-symbol attributes" do
        expect { type.cast(5) }.to raise_error(Amount::InvalidInput, /raw numeric assignment requires a fixed symbol/)
      end

      it "raises InvalidInput for unsupported classes" do
        expect { type.cast(Object.new) }.to raise_error(Amount::InvalidInput, /cannot cast Object to Amount/)
      end
    end

    describe "#deserialize" do
      it "builds an Amount from a (atomic, symbol) pair" do
        expect(type.deserialize("1500000", "USDC")).to eq_amount("USDC|1.5")
      end

      it "returns nil when atomic is nil (column was unset)" do
        expect(type.deserialize(nil, "USDC")).to be_nil
      end

      it "returns nil when both atomic and resolvable symbol are missing" do
        expect(type.deserialize("1500000", nil)).to be_nil
      end
    end

    describe "#dump" do
      it "round-trips an Amount into a {atomic:, symbol:} payload" do
        expect(type.dump(Amount.usdc("1.5"))).to eq(atomic: 1_500_000, symbol: :USDC)
      end

      it "returns nil for nil" do
        expect(type.dump(nil)).to be_nil
      end

      it "casts non-Amount input first, then dumps" do
        expect(type.dump("USDC|1.5")).to eq(atomic: 1_500_000, symbol: :USDC)
      end
    end
  end

  describe "fixed-symbol Type (symbol: :SOL)" do
    subject(:type) { described_class.new(symbol: :SOL) }

    it "remembers the fixed_symbol" do
      expect(type.fixed_symbol).to eq(:SOL)
    end

    describe "#cast" do
      it "accepts raw numerics as UI values in the fixed symbol" do
        expect(type.cast(1.5)).to eq_amount("SOL|1.5")
        expect(type.cast(BigDecimal("1.5"))).to eq_amount("SOL|1.5")
        expect(type.cast(2)).to eq_amount(:SOL, "2")
      end

      it "accepts a matching-symbol Amount" do
        amount = Amount.sol("1")
        expect(type.cast(amount)).to be(amount)
      end

      it "raises TypeMismatch for an Amount with the wrong symbol" do
        expect { type.cast(Amount.usdc("1")) }.to raise_error(Amount::TypeMismatch, /expected SOL/)
      end

      it "still parses compact strings (must match the fixed symbol)" do
        expect(type.cast("SOL|1.5")).to eq_amount(:SOL, "1.5")
        expect { type.cast("USDC|1.5") }.to raise_error(Amount::TypeMismatch)
      end
    end

    describe "#deserialize" do
      it "uses the fixed_symbol when no symbol is provided" do
        expect(type.deserialize("1500000000")).to eq_amount(:SOL, "1.5")
      end

      it "honors an explicit symbol argument that matches" do
        expect(type.deserialize("1500000000", "SOL")).to eq_amount(:SOL, "1.5")
      end
    end

    describe "#dump" do
      it "writes the atomic and symbol pair" do
        expect(type.dump(Amount.sol("0.5"))).to eq(atomic: 500_000_000, symbol: :SOL)
      end
    end
  end

  describe "construction with a String symbol" do
    it "accepts symbol: 'SOL' and stores as a Symbol" do
      type = described_class.new(symbol: "SOL")
      expect(type.fixed_symbol).to eq(:SOL)
    end
  end
end
