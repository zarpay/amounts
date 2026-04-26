require "rails_helper"
require "json"

# =============================================================================
# Torture spec — the harness's working journal of adversarial inputs
# =============================================================================
#
# This file is where the harness throws deliberately hostile / cursed
# inputs at the gem to see what breaks. Findings are surfaced as failing
# examples; expected-correct behaviors are positive assertions; remaining
# limitations are `pending` with a clear explanation.
#
# Every bug fixed in 0.0.2 / 0.0.3 / 0.0.4 / 0.0.5 was either surfaced or
# corroborated here. Categories covered:
#
#   numeric extremes              huge atomics, NaN, Infinity, decimals: 30
#                                 with Rational, decimals: 0 with split(1)
#
#   symbol weirdness              empty string, nil, unicode, Ruby
#                                 keywords, collisions with existing
#                                 Amount class methods, register-after-clear
#
#   format-string-injection       display_symbol containing "%s" / "%" /
#                                 empty string
#
#   rate-registration weirdness   self-rate (:A -> :A), rate of 0,
#                                 negative rate
#
#   Amount.parse format hostility  scientific notation, leading +, leading .,
#                                  underscores, whitespace, multiple pipes,
#                                  missing pipe
#
#   serialization round-trips     JSON via to_h with huge atomics,
#                                 negative atomics, Marshal.dump/load
#
#   concurrency stress            concurrent reads, concurrent
#                                 clear+register cycles
#
#   Comparable + Enumerable       sum, min, max, sort across heterogeneous
#                                 symbols
#
#   frozen / immutability         render display on a frozen Amount
#                                 (fixed in 0.0.4)
#
#   Amount equality with          nil, String, Integer
#   non-Amount objects
RSpec.describe "Torture / edge-case probing", :aggregate_failures do
  describe "numeric extremes" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        Amount.register :X, decimals: 6, display_symbol: "X", display_position: :suffix, ui_decimals: 2
        example.run
      end
    end

    it "stores atomic values up to 2**256 - 1 exactly (in-memory only)" do
      huge = (2**256) - 1
      a = Amount.new(huge, :X, from: :atomic)
      expect(a.atomic).to eq(huge)
      expect((a + Amount.new(1, :X, from: :atomic)).atomic).to eq(huge + 1)
    end

    it "rejects Float::INFINITY as a UI input (currently leaks FloatDomainError; consider wrapping)" do
      expect { Amount.new(Float::INFINITY, :X) }.to raise_error(FloatDomainError)
    end

    it "rejects Float::NAN as a UI input (currently leaks FloatDomainError; consider wrapping)" do
      expect { Amount.new(Float::NAN, :X) }.to raise_error(FloatDomainError)
    end

    it "treats Amount * 0 as zero, not as identity" do
      result = Amount.new("5", :X) * 0
      expect(result.atomic).to eq(0)
      expect(result.zero?).to be(true)
    end

    it "rejects multiplication by Float::INFINITY" do
      expect {
        Amount.new("1", :X) * Float::INFINITY
      }.to raise_error(StandardError) # whatever it is, should not silently produce nonsense
    end

    it "handles decimals: 30 (huge UI precision) with exact Rational integer math" do
      Amount.register :TINY, decimals: 30, display_symbol: "t", display_position: :suffix, ui_decimals: 0
      a = Amount.new(Rational(1, 3), :TINY)
      # 1/3 truncated toward zero at 30 decimals: exactly 30 threes.
      expect(a.atomic.to_s).to eq("3" * 30)
    end

    it "supports decimals: 0 (LOGS-like) plus split(1) returning the whole thing" do
      Amount.register :ONE, decimals: 0, display_symbol: "u", display_position: :suffix, ui_decimals: 0
      parts, rem = Amount.new(7, :ONE).split(1)
      expect(parts.map(&:atomic)).to eq([7])
      expect(rem.atomic).to eq(0)
    end

    it "supports allocate with one massive weight and a tiny one (ratio preserved)" do
      Amount.register :ONE, decimals: 0, display_symbol: "u", display_position: :suffix, ui_decimals: 0
      parts, rem = Amount.new(100, :ONE).allocate([99, 1])
      expect(parts.map(&:atomic)).to eq([99, 1])
      expect(rem.atomic).to eq(0)
    end
  end

  describe "symbol weirdness" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        example.run
      end
    end

    it "rejects an empty-string symbol with ArgumentError (fixed in 0.0.4)" do
      expect { Amount.register :"", decimals: 2 }.to raise_error(ArgumentError, /symbol must not be blank/)
    end

    it "rejects a nil symbol with ArgumentError (fixed in 0.0.4)" do
      expect { Amount.register nil, decimals: 2 }.to raise_error(ArgumentError, /symbol must not be blank/)
    end

    it "registers a unicode symbol and constructs an Amount" do
      Amount.register :"€EUR", decimals: 2, display_symbol: "€", display_position: :prefix, ui_decimals: 2
      a = Amount.new("1.50", :"€EUR")
      expect(a.atomic).to eq(150)
      expect(a.symbol).to eq(:"€EUR")
      expect(a.ui).to eq("€1.50")
    end

    it "skips constructor generation for unicode (not a method-safe name)" do
      Amount.register :"€EUR", decimals: 2
      expect(Amount).not_to respond_to(:"€EUR")
    end

    it "round-trips parse/to_s for a unicode symbol" do
      Amount.register :"€EUR", decimals: 2
      original = Amount.new("1.50", :"€EUR")
      restored = Amount.parse(original.to_s)
      expect(restored).to eq(original)
    end

    it "rejects registering a symbol that collides with an existing Amount class method" do
      expect { Amount.register :registry, decimals: 2 }.to raise_error(Amount::Registry::AlreadyRegistered)
    end

    it "tolerates a Ruby keyword-named symbol (:end, :while)" do
      Amount.register :end, decimals: 2
      expect(Amount.new("1", :end).atomic).to eq(100)
    end

    it "lets the same symbol re-register cleanly after clear!" do
      Amount.register :Z, decimals: 2
      Amount.registry.clear!
      Amount.register :Z, decimals: 4
      expect(Amount.new(1, :Z, from: :atomic).decimals).to eq(4)
    end
  end

  describe "format-string-injection display symbols" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        example.run
      end
    end

    it "renders a display_symbol containing '%s' literally, not as a format directive" do
      Amount.register :PCT, decimals: 2, display_symbol: "%s", display_position: :prefix, ui_decimals: 2
      expect(Amount.new("1", :PCT).ui).to eq("%s1.00")
    end

    it "renders a display_symbol containing '%' inside format()" do
      Amount.register :PCNT, decimals: 2, display_symbol: "%", display_position: :suffix, ui_decimals: 2
      expect(Amount.new("1.5", :PCNT).ui).to eq("1.50 %")
    end

    it "renders an empty display_symbol cleanly" do
      Amount.register :NOSYM, decimals: 2, display_symbol: "", display_position: :prefix, ui_decimals: 2
      result = Amount.new("1", :NOSYM).ui
      expect(result).to match(/\A\s*1\.00\s*\z/)
    end
  end

  describe "rate-registration weirdness" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        Amount.register :A, decimals: 2
        Amount.register :B, decimals: 2
        example.run
      end
    end

    it "tolerates a self-directed rate (:A -> :A) registration" do
      Amount.register_default_rate :A, :A, 1
      expect(Amount.registry.default_rate(:A, :A)).to eq(BigDecimal("1"))
    end

    it "tolerates a rate of 0 (mathematically degenerate but registry-valid)" do
      Amount.register_default_rate :A, :B, 0
      result = Amount.new("1", :A).to(:B)
      expect(result.atomic).to eq(0)
    end

    it "tolerates a negative rate" do
      Amount.register_default_rate :A, :B, -1
      result = Amount.new("1", :A).to(:B)
      expect(result.decimal).to eq(BigDecimal("-1"))
    end
  end

  describe "Amount.parse format hostility" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        Amount.register :Y, decimals: 6, display_symbol: "Y", display_position: :suffix, ui_decimals: 2
        example.run
      end
    end

    it "accepts scientific notation in the value half" do
      expect(Amount.parse("Y|1e3").decimal).to eq(BigDecimal("1000"))
      expect(Amount.parse("Y|1.5e-3").decimal).to eq(BigDecimal("0.0015"))
    end

    it "accepts a leading + sign on the value" do
      expect(Amount.parse("Y|+1.5").decimal).to eq(BigDecimal("1.5"))
    end

    it "accepts a leading dot on the value" do
      expect(Amount.parse("Y|.5").decimal).to eq(BigDecimal("0.5"))
    end

    it "permissively accepts underscored values (BigDecimal accepts them in Ruby 3.1+)" do
      # Documenting the actual behavior — `BigDecimal("1_000")` returns 1000.
      # Ruby's permissive numeric literal parsing is inherited.
      expect(Amount.parse("Y|1_000").decimal).to eq(BigDecimal("1000"))
    end

    it "permissively accepts whitespace around the value (BigDecimal strips it)" do
      expect(Amount.parse("Y| 1.5 ").decimal).to eq(BigDecimal("1.5"))
    end

    it "splits on the FIRST '|' so subsequent pipes are treated as part of the value (and rejected)" do
      expect { Amount.parse("Y|1|2") }.to raise_error(Amount::InvalidInput)
    end

    it "rejects a missing pipe" do
      expect { Amount.parse("Y1.5") }.to raise_error(Amount::InvalidInput)
    end
  end

  describe "serialization round-trips" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        Amount.register :Z, decimals: 6, display_symbol: "Z", display_position: :suffix, ui_decimals: 2
        example.run
      end
    end

    it "round-trips through JSON via to_h (atomic survives as a string)" do
      original = Amount.new(2**100, :Z, from: :atomic)
      restored = Amount.load(JSON.parse(JSON.dump(original.to_h)))
      expect(restored.atomic).to eq(original.atomic)
      expect(restored.symbol).to eq(:Z)
    end

    it "round-trips a tiny value through JSON" do
      original = Amount.new(1, :Z, from: :atomic)
      restored = Amount.load(JSON.parse(JSON.dump(original.to_h)))
      expect(restored).to eq(original)
    end

    it "round-trips a negative value through JSON" do
      original = Amount.new(-12345, :Z, from: :atomic)
      restored = Amount.load(JSON.parse(JSON.dump(original.to_h)))
      expect(restored).to eq(original)
    end

    it "Marshal.dump/load round-trips" do
      original = Amount.new("3.14", :Z)
      restored = Marshal.load(Marshal.dump(original))
      expect(restored).to eq(original)
    end
  end

  describe "concurrency stress" do
    around do |example|
      Amount.with_registry(Amount::Registry.new) do
        example.run
      end
    end

    it "tolerates 50 threads × 100 concurrent reads without crashing" do
      Amount.register :C, decimals: 2
      threads = 50.times.map do
        Thread.new do
          100.times { Amount.registry.lookup(:C) }
        end
      end
      expect { threads.each(&:join) }.not_to raise_error
    end

    it "serializes 20 concurrent same-symbol re-clears + registers without crashing" do
      Amount.register :CC, decimals: 2
      errors = []
      threads = 20.times.map do
        Thread.new do
          Amount.registry.clear!
          Amount.register :CC, decimals: 2
        rescue Amount::Registry::AlreadyRegistered
          # benign race — another thread already registered
        rescue => e
          errors << e
        end
      end
      threads.each(&:join)
      expect(errors).to be_empty
    end
  end

  describe "Comparable + Enumerable interactions" do
    it "Enumerable#sum needs an explicit zero amount (Ruby's default 0 is an Integer)" do
      amounts = [Amount.usdc("1"), Amount.usdc("2"), Amount.usdc("3")]
      total = amounts.sum(Amount.usdc(0, from: :atomic))
      expect(total).to eq_amount("USDC|6.0")
    end

    it "Enumerable#sum without explicit zero raises (Integer + Amount has no rate)" do
      amounts = [Amount.usdc("1"), Amount.usdc("2")]
      expect { amounts.sum }.to raise_error(StandardError)
    end

    it "Array#min / Array#max work for same-symbol amounts" do
      amounts = [Amount.usdc("1"), Amount.usdc("3"), Amount.usdc("2")]
      expect(amounts.min).to eq_amount("USDC|1.0")
      expect(amounts.max).to eq_amount("USDC|3.0")
    end

    it "Array#sort raises on heterogeneous symbols without a rate" do
      Amount.register :NORATE, decimals: 2 unless Amount.registry.registered?(:NORATE)
      amounts = [Amount.usdc("1"), Amount.new("1", :NORATE)]
      expect { amounts.sort }.to raise_error(ArgumentError)
    end
  end

  describe "frozen / immutability" do
    it "lets a frozen Amount participate in arithmetic (no internal mutation)" do
      a = Amount.usdc("1").freeze
      b = Amount.usdc("2").freeze
      expect((a + b)).to eq_amount("USDC|3.0")
    end

    it "computes display on a frozen Amount without raising (fixed in 0.0.4)" do
      a = Amount.usdc("1.50").freeze
      expect(a.ui).to eq("$1.50")
      expect(a.formatted).to eq("1.500000")
      expect(a.to_s).to eq("USDC|1.5")
    end
  end

  describe "Amount equality with non-Amount objects" do
    it "returns false against nil" do
      expect(Amount.usdc("1") == nil).to be(false)
    end

    it "returns false against a String even if it 'looks like' the value" do
      expect(Amount.usdc("1") == "USDC|1.0").to be(false)
    end

    it "returns false against an Integer matching the atomic" do
      expect(Amount.usdc(1_000_000, from: :atomic) == 1_000_000).to be(false)
    end
  end
end
