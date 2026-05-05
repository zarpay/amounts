require "rails_helper"

# =============================================================================
# Registry spec — the configuration surface of the gem
# =============================================================================
#
# This file covers the registry itself: registration options, locking,
# error classes, generated constructors, thread safety, and the test-time
# `Amount.with_registry` helper.
#
# Two outer describes:
#
#   "the production-loaded application registry"
#       Asserts that the boot-time initializer in
#       config/initializers/amounts.rb registered every cookbook symbol
#       with the right shape, and that the directional default rates are
#       in place.
#
#   "isolated registry via Amount.with_registry"
#       Each example runs against a fresh empty registry. This is where
#       error classes (UnknownType, AlreadyRegistered, RegistryLocked,
#       InvalidDisplayUnit, NoDefaultRate) get exercised, since they
#       require precise control over what is and isn't registered.

RSpec.describe "Amount registry", :aggregate_failures do
  describe "the production-loaded application registry" do
    include_context "with the application registry"

    it "has every cookbook symbol registered" do
      expect(Amount.registry.symbols).to include(:USDC, :USD, :SOL, :GOLD, :LOGS, :EMBER, :SILVER)
    end

    it "exposes generated constructors for every well-named symbol" do
      expect(Amount.of_usdc("1.50")).to be_amount_of(:USDC)
      expect(Amount.of_sol("0.5")).to be_amount_of(:SOL)
      expect(Amount.of_gold("1.0")).to be_amount_of(:GOLD)
      expect(Amount.of_logs(10)).to be_amount_of(:LOGS)
      expect(Amount.of_ember("1.0")).to be_amount_of(:EMBER)
      expect(Amount.of_silver("1.0")).to be_amount_of(:SILVER)
    end

    it "carries directional default rates as registered" do
      expect(Amount.registry.default_rate?(:USD, :USDC)).to be(true)
      expect(Amount.registry.default_rate?(:USDC, :USD)).to be(true)
      expect(Amount.registry.default_rate?(:SOL, :USDC)).to be(true)
      expect(Amount.registry.default_rate(:SOL, :USDC)).to eq(BigDecimal("150.00"))
    end

    it "treats the registry as case-sensitive on the symbol" do
      expect(Amount.registry.registered?(:USDC)).to be(true)
      expect(Amount.registry.registered?(:usdc)).to be(false)
    end
  end

  describe "isolated registry via Amount.with_registry" do
    include_context "with an isolated registry"

    it "swaps the global registry for the duration of the block" do
      Amount.register :TEST, decimals: 2
      expect(Amount.registry.symbols).to eq([:TEST])
    end

    it "raises UnknownType for unregistered symbols" do
      expect { Amount.new("1", :MISSING) }.to raise_error(Amount::Registry::UnknownType)
    end

    it "exposes the gem error subclasses through Amount::Error" do
      expect(Amount::Registry::UnknownType.ancestors).to include(StandardError)
      expect(Amount::TypeMismatch.ancestors).to include(Amount::Error)
      expect(Amount::InvalidInput.ancestors).to include(Amount::Error)
    end

    context "lock!" do
      before do
        Amount.register :LCK, decimals: 0
        Amount.registry.lock!
      end

      it "freezes further registration" do
        expect { Amount.register :OTHER, decimals: 0 }.to raise_error(Amount::Registry::RegistryLocked)
      end

      it "freezes default rate registration" do
        Amount.with_registry(Amount::Registry.new) do
          Amount.register :A, decimals: 0
          Amount.register :B, decimals: 0
          Amount.registry.lock!
          expect { Amount.register_default_rate(:A, :B, "1") }.to raise_error(Amount::Registry::RegistryLocked)
        end
      end

      it "still allows reads after locking" do
        expect(Amount.registry.lookup(:LCK)).to be_a(Amount::Registry::Entry)
        expect(Amount.registry).to be_locked
      end

      it "freezes clear!" do
        expect { Amount.registry.clear! }.to raise_error(Amount::Registry::RegistryLocked)
      end
    end

    it "rejects duplicate generated-constructor names" do
      Amount.register :MET, decimals: 2
      expect { Amount.register :MET, decimals: 4 }.to raise_error(Amount::Registry::AlreadyRegistered)
    end

    it "skips constructor generation for symbols that aren't valid Ruby method names" do
      Amount.register :"USDC.e", decimals: 6
      expect(Amount.registry.registered?(:"USDC.e")).to be(true)
      expect(Amount).not_to respond_to(:"of_USDC.e")
      expect(Amount).not_to respond_to(:of_usdc_e)
    end

    it "downcases multi-word symbols into snake_case generated constructors" do
      Amount.register :OIL_WTI_BBL, decimals: 4
      expect(Amount).to respond_to(:of_oil_wti_bbl)
      expect(Amount.of_oil_wti_bbl("1.5")).to eq_amount(:OIL_WTI_BBL, "1.5")
      expect(Amount.of_oil_wti_bbl(15_000, from: :atomic).atomic).to eq(15_000)
    end

    it "registers ISO codes that collide with ActiveSupport methods on Object" do
      # Object#try is defined by ActiveSupport, so the unprefixed name
      # `Amount.try` would clash. The `of_` prefix sidesteps the collision
      # entirely — see the original bug for :TRY (Turkish Lira).
      expect(Object.instance_method(:try)).to be_a(UnboundMethod)
      expect { Amount.register :TRY, decimals: 2 }.not_to raise_error
      expect(Amount.of_try("100")).to eq_amount(:TRY, "100")
    end

    it "exposes registry_entry directly on a constructed Amount" do
      Amount.register :ENT, decimals: 6, ui_decimals: 2, display_symbol: "E"
      entry = Amount.new("1", :ENT).registry_entry
      expect(entry).to be_a(Amount::Registry::Entry)
      expect(entry.symbol).to eq(:ENT)
      expect(entry.decimals).to eq(6)
      expect(entry.ui_decimals).to eq(2)
      expect(entry.display_symbol).to eq("E")
    end

    it "validates display_units when default_display is missing from the units hash" do
      expect {
        Amount.register :BAD, decimals: 2, display_units: { foo: { scale: 1 } }, default_display: :missing
      }.to raise_error(Amount::Registry::InvalidDisplayUnit)
    end

    it "raises NoDefaultRate when no rate is registered" do
      Amount.register :A, decimals: 2
      Amount.register :B, decimals: 2
      expect { Amount.registry.default_rate(:A, :B) }.to raise_error(Amount::Registry::NoDefaultRate)
    end

    it "is thread-safe for concurrent reads" do
      Amount.register :T, decimals: 2
      results = 10.times.map { Thread.new { 100.times.map { Amount.registry.lookup(:T) } } }.flat_map(&:value)
      expect(results.size).to eq(1000)
      expect(results.all? { |e| e.is_a?(Amount::Registry::Entry) }).to be(true)
    end
  end

  describe ".registry.clear!" do
    include_context "with an isolated registry"

    it "removes all entries, rates, and generated constructors" do
      Amount.register :CLR, decimals: 2
      expect(Amount).to respond_to(:of_clr)
      Amount.registry.clear!
      expect(Amount.registry.symbols).to be_empty
      expect(Amount).not_to respond_to(:of_clr)
    end
  end
end
