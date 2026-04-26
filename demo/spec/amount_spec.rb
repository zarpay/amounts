require "rails_helper"

# =============================================================================
# Amount spec — pure value-object behavior
# =============================================================================
#
# This file is the broadest single spec in the harness. Every public
# instance and class method on `Amount` lands in one of these describe
# blocks:
#
#   construction          Integer / String / Float / BigDecimal / Rational
#                         input inference, `from:` overrides, large atomics,
#                         unknown symbols
#
#   predicates            zero? / positive? / negative? / same_type?
#
#   unary / abs           -@, abs (preserve subclass identity)
#
#   arithmetic            +, -, *, / for same-type and cross-type via
#                         registered rates; scalar BigDecimal/Float;
#                         Rational scalars (post-0.0.3); failure modes
#                         (TypeMismatch, ZeroDivisionError)
#
#   comparison            <=>, ==, eql?, hash, sortability
#
#   conversion .to        identity, registered rate, explicit rate,
#                         NoDefaultRate
#
#   split / allocate      part-and-remainder invariants, negative-amount
#                         rounding-toward-zero, ArgumentError edge cases
#
#   display / formatting  formatted, ui (default + ceil + per-unit),
#                         in_unit, to_s, InvalidDisplayUnit
#
#   serialization         to_h shape, parse, load (versioned + legacy +
#                         string keys + missing keys + future versions)
#
#   custom subclass       Amount.with_registry isolation, identity
#                         through arithmetic / split / matchers

RSpec.describe Amount, :aggregate_failures do
  subject(:amount) { Amount.usdc("1.50") }

  describe "construction" do
    it "treats Integer input as atomic units" do
      expect(Amount.new(1_500_000, :USDC).atomic).to eq(1_500_000)
      expect(Amount.new(1_500_000, :USDC).decimal).to eq(BigDecimal("1.5"))
    end

    it "treats String, Float, BigDecimal input as UI value" do
      expect(Amount.new("1.50", :USDC).atomic).to eq(1_500_000)
      expect(Amount.new(1.5, :USDC).atomic).to eq(1_500_000)
      expect(Amount.new(BigDecimal("1.5"), :USDC).atomic).to eq(1_500_000)
    end

    it "accepts Rational UI input via exact integer math (fixed in 0.0.2)" do
      expect(Amount.new(Rational(3, 2), :USDC).atomic).to eq(1_500_000)
    end

    it "truncates repeating-fraction Rationals toward zero" do
      expect(Amount.new(Rational(1, 3), :USDC).atomic).to eq(333_333)
    end

    it "respects from: :atomic / :ui / :float overrides" do
      expect(Amount.new("1500000", :USDC, from: :atomic).atomic).to eq(1_500_000)
      expect(Amount.new("1.5", :USDC, from: :ui).atomic).to eq(1_500_000)
      expect(Amount.new(1.5, :USDC, from: :float).atomic).to eq(1_500_000)
    end

    it "raises UnknownType for unregistered symbols" do
      expect { Amount.new("1", :NOPE) }.to raise_error(Amount::Registry::UnknownType)
    end

    it "raises InvalidInput for unparseable values" do
      expect { Amount.new("abc", :USDC) }.to raise_error(Amount::InvalidInput)
    end

    it "supports very large atomic values up to 10**30" do
      huge = 10**30
      a = Amount.new(huge, :USDC, from: :atomic)
      expect(a.atomic).to eq(huge)
    end
  end

  describe "predicates" do
    specify { expect(Amount.usdc(0, from: :atomic)).to be_zero_amount }
    specify { expect(Amount.usdc("1")).to be_positive_amount }
    specify { expect(Amount.usdc("-1")).to be_negative_amount }

    it "checks same_type?" do
      expect(Amount.usdc("1").same_type?(Amount.usdc("2"))).to be(true)
      expect(Amount.usdc("1").same_type?(Amount.sol("1"))).to be(false)
      expect(Amount.usdc("1").same_type?("not an amount")).to be(false)
    end
  end

  describe "unary / abs / negation" do
    it { expect(-Amount.usdc("1")).to eq_amount("USDC|-1.0") }
    it { expect(Amount.usdc("-2.5").abs).to eq_amount("USDC|2.5") }
  end

  describe "arithmetic" do
    let(:a) { Amount.usdc("1.50") }
    let(:b) { Amount.usdc("0.50") }

    it { expect(a + b).to eq_amount("USDC|2.0") }
    it { expect(a - b).to eq_amount("USDC|1.0") }
    it { expect(a * 2).to eq_amount("USDC|3.0") }
    it { expect(a * 1.5).to eq_amount(:USDC, "2.25") }
    it { expect(a / 2).to eq_amount("USDC|0.75") }

    it "returns BigDecimal for same-type division" do
      expect(a / b).to eq(BigDecimal("3"))
    end

    it "raises TypeMismatch for Amount * Amount" do
      expect { a * b }.to raise_error(Amount::TypeMismatch)
    end

    it "raises ZeroDivisionError for divide by zero amount" do
      expect { a / Amount.usdc(0, from: :atomic) }.to raise_error(ZeroDivisionError)
    end

    it "preserves negative scalar multiplication" do
      expect(Amount.usdc("-1") * -2).to eq_amount("USDC|2.0")
    end

    it "accepts a BigDecimal scalar" do
      expect(Amount.usdc("2") * BigDecimal("1.5")).to eq_amount("USDC|3.0")
    end

    it "accepts a Rational scalar (fixed in 0.0.3)" do
      expect(Amount.usdc("2") * Rational(3, 2)).to eq_amount("USDC|3.0")
    end

    it "accepts a Rational divisor (fixed in 0.0.3)" do
      expect(Amount.usdc("3") / Rational(3, 2)).to eq_amount("USDC|2.0")
    end

    it "rejects non-numeric scalar" do
      expect { Amount.usdc("1") * "two" }.to raise_error(Amount::TypeMismatch)
    end

    context "cross-type via default rate" do
      it "coerces RHS into LHS during +" do
        sum = Amount.usdc("1") + Amount.usd("2")
        expect(sum).to be_amount_of(:USDC)
        expect(sum.decimal).to eq(BigDecimal("3"))
      end

      it "raises TypeMismatch when no rate exists" do
        expect { Amount.ember("1") + Amount.usdc("1") }.to raise_error(Amount::TypeMismatch)
      end
    end
  end

  describe "comparison" do
    it "implements Comparable" do
      sorted = [Amount.usdc("3"), Amount.usdc("1"), Amount.usdc("2")].sort
      expect(sorted.map(&:decimal)).to eq([BigDecimal("1"), BigDecimal("2"), BigDecimal("3")])
    end

    it "returns nil for cross-type comparison without a rate" do
      expect(Amount.ember("1") <=> Amount.usdc("1")).to be_nil
    end

    it "compares cross-type when a rate exists" do
      expect(Amount.usd("1.00") <=> Amount.usdc("0.99")).to eq(1)
    end

    it "treats == as strict same-symbol same-atomic" do
      expect(Amount.usdc("1") == Amount.usdc("1")).to be(true)
      expect(Amount.usdc("1") == Amount.usd("1")).to be(false)
    end

    it "uses [class, symbol, atomic] for hash" do
      a = Amount.usdc("1")
      b = Amount.usdc("1")
      expect(a.hash).to eq(b.hash)
      expect({ a => "x" }[b]).to eq("x")
    end
  end

  describe "conversion .to" do
    it "is identity for the same symbol" do
      expect(Amount.usdc("1.50").to(:USDC)).to eq_amount("USDC|1.5")
    end

    it "uses the registered default rate" do
      result = Amount.usd("1").to(:USDC)
      expect(result).to be_amount_of(:USDC)
      expect(result.decimal).to eq(BigDecimal("1"))
    end

    it "accepts an explicit one-off rate" do
      result = Amount.gold("1").to(:USDC, rate: "2000")
      expect(result.decimal).to eq(BigDecimal("2000"))
    end

    it "raises NoDefaultRate without a registered or explicit rate" do
      expect { Amount.ember("1").to(:USDC) }.to raise_error(Amount::Registry::NoDefaultRate)
    end
  end

  describe "split / allocate" do
    it "splits evenly with remainder" do
      parts, remainder = Amount.logs(10).split(3)
      expect(parts.map(&:atomic)).to eq([3, 3, 3])
      expect(remainder.atomic).to eq(1)
    end

    it "allocates by weights" do
      parts, remainder = Amount.logs(10).allocate([1, 1, 2])
      expect(parts.map(&:atomic)).to eq([2, 2, 5])
      expect(remainder.atomic).to eq(1)
    end

    it "preserves the invariant parts.sum + remainder == original" do
      original = Amount.logs(123)
      parts, remainder = original.split(7)
      expect(parts.sum(&:atomic) + remainder.atomic).to eq(original.atomic)
    end

    it "raises ArgumentError for non-positive split count" do
      expect { Amount.logs(10).split(0) }.to raise_error(ArgumentError)
      expect { Amount.logs(10).split(-1) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for empty / all-zero / negative weights" do
      expect { Amount.logs(10).allocate([]) }.to raise_error(ArgumentError)
      expect { Amount.logs(10).allocate([0, 0]) }.to raise_error(ArgumentError)
      expect { Amount.logs(10).allocate([1, -1]) }.to raise_error(ArgumentError)
    end

    it "rounds toward zero for negative amounts" do
      parts, remainder = Amount.logs(-10).split(3)
      expect(parts.map(&:atomic)).to all(be <= 0)
      expect(parts.sum(&:atomic) + remainder.atomic).to eq(-10)
    end
  end

  describe "display / formatting" do
    it "renders default ui with prefix symbol when configured" do
      expect(Amount.usdc("1.50").ui).to eq("$1.50")
    end

    it "renders default ui with suffix symbol when configured" do
      expect(Amount.sol("1.5").ui).to match(/\A1\.5000 SOL\z/)
    end

    it "supports :floor (default) and :ceil rounding" do
      expect(Amount.usdc("1.567").ui).to eq("$1.56")
      expect(Amount.usdc("1.561").ui(direction: :ceil)).to eq("$1.57")
    end

    it "renders display units" do
      expect(Amount.gold("1.0").ui(unit: :gram)).to eq("31.10 g")
      expect(Amount.gold("1.0").ui(unit: :kg)).to eq("0.03110 kg")
    end

    it "raises InvalidDisplayUnit for unknown unit" do
      expect { Amount.gold("1.0").ui(unit: :ounce) }.to raise_error(Amount::Registry::InvalidDisplayUnit)
    end

    it "respects per-unit position: override (units can flip prefix vs entry default suffix)" do
      isolated = Amount::Registry.new
      Amount.with_registry(isolated) do
        Amount.register :MIXED,
          decimals: 4,
          display_symbol: "x",
          display_position: :suffix,
          ui_decimals: 2,
          display_units: {
            base:    { scale: 1, symbol: "x", ui_decimals: 2 },
            prefixed: { scale: 100, symbol: "p", position: :prefix, ui_decimals: 0 }
          },
          default_display: :base

        suffix_render  = Amount.new("1", :MIXED).ui
        prefix_render  = Amount.new("1", :MIXED).ui(unit: :prefixed)

        expect(suffix_render).to match(/\A1\.00 x\z/)
        expect(prefix_render).to match(/\Ap100\z/)
      end
    end

    it "returns raw scaled BigDecimal via in_unit" do
      expect(Amount.gold("1.0").in_unit(:gram)).to eq(BigDecimal("31.1035"))
    end

    it "renders formatted (raw, no symbol)" do
      expect(Amount.usdc("1.5").formatted).to eq("1.500000")
    end

    it "renders compact to_s" do
      expect(Amount.usdc("1.5").to_s).to eq("USDC|1.5")
    end
  end

  describe "serialization" do
    it "to_h emits versioned hash with atomic-as-string" do
      h = Amount.usdc("1.50").to_h
      expect(h).to eq(v: 1, atomic: "1500000", symbol: "USDC")
    end

    it "round-trips via to_h / load" do
      original = Amount.usdc("1.50")
      restored = Amount.load(original.to_h)
      expect(restored).to eq_amount(original)
    end

    it "accepts legacy unversioned hash" do
      restored = Amount.load(atomic: 1_500_000, symbol: :USDC)
      expect(restored).to eq_amount("USDC|1.5")
    end

    it "accepts legacy unversioned hash with string keys" do
      restored = Amount.load("atomic" => 1_500_000, "symbol" => "USDC")
      expect(restored).to eq_amount("USDC|1.5")
    end

    it "accepts current versioned hash with string keys" do
      restored = Amount.load("v" => 1, "atomic" => "1500000", "symbol" => "USDC")
      expect(restored).to eq_amount("USDC|1.5")
    end

    it "rejects future versions" do
      expect { Amount.load(v: 2, atomic: "1", symbol: "USDC") }.to raise_error(Amount::InvalidInput)
    end

    it "parses compact strings with optional version prefix" do
      expect(Amount.parse("USDC|1.50")).to eq_amount("USDC|1.5")
      expect(Amount.parse("v1:USDC|1.50")).to eq_amount("USDC|1.5")
      expect { Amount.parse("v2:USDC|1.50") }.to raise_error(Amount::InvalidInput)
      expect { Amount.parse("USDC|") }.to raise_error(Amount::InvalidInput)
      expect { Amount.parse("|1.50") }.to raise_error(Amount::InvalidInput)
    end
  end

  describe "custom subclass via Amount.with_registry" do
    around do |example|
      isolated = Amount::Registry.new
      Amount.with_registry(isolated) { example.run }
    end

    let(:purity_class) do
      Class.new(Amount) do
        def boost; self * 2; end
      end
    end

    before do
      stub_const("PurityAmount", purity_class)
      Amount.register :PURE, decimals: 4, class: PurityAmount
    end

    it "constructs the subclass via the generated constructor" do
      expect(Amount.pure("1").class).to eq(PurityAmount)
    end

    it "preserves subclass identity through arithmetic" do
      expect((Amount.pure("1") + Amount.pure("1")).class).to eq(PurityAmount)
    end

    it "preserves subclass identity through split" do
      parts, _ = Amount.pure("3").split(2)
      expect(parts.map(&:class)).to all(eq(PurityAmount))
    end

    it "auto-dispatches Amount.new to the registered subclass (fixed in 0.0.2)" do
      expect(Amount.new("1", :PURE)).to be_a(PurityAmount)
    end

    it "still raises InvalidInput for an explicit wrong subclass" do
      other = Class.new(Amount)
      expect { other.new("1", :PURE) }.to raise_error(Amount::InvalidInput, /use PurityAmount\.new/)
    end

    it "exposes subclass methods" do
      expected = PurityAmount.new("2", :PURE)
      expect(Amount.pure("1").boost).to eq(expected)
    end
  end
end
