# frozen_string_literal: true

require "bigdecimal"
require "forwardable"

require_relative "amount/version"
require_relative "amount/registry"
require_relative "amount/display"
require_relative "amount/parser"
require_relative "amount/arithmetic"
require_relative "amount/allocation"
require_relative "amount/comparison"
require_relative "amount/conversion"
require_relative "amount/serialization"

# Represents a precise quantity of a registered fungible type.
#
# `Amount` stores its value as an arbitrary-precision atomic `Integer` in the
# smallest unit configured for the registered symbol. UI values are parsed from
# strings or decimals, while integer inputs are treated as atomic counts unless
# `from:` overrides inference.
#
# Behavior is composed from a set of focused mixins:
# - {Arithmetic}    — `+`, `-`, `*`, `/`, `abs`, `-@`
# - {Comparison}    — `<=>`, `==`, `eql?`, `hash`, `same_type?`, sign predicates
# - {Conversion}    — `to(:SYMBOL, rate:)`
# - {Allocation}    — `split(n)`, `allocate(weights)`
# - {Serialization} — `to_h`
#
# @example Constructing from a UI value
#   Amount.register :USDC, decimals: 6
#
#   Amount.usdc("1.50").atomic
#   # => 1500000
#
# @example Constructing from an atomic value
#   Amount.usdc(1_500_000, from: :atomic).decimal.to_s("F")
#   # => "1.5"
class Amount
  include Comparable
  extend Forwardable

  class Error < StandardError; end
  class TypeMismatch < Error; end
  class InvalidInput < Error; end
  class UnregisteredType < Error; end

  class << self
    # @return [Amount::Registry]
    # @example Accessing the shared registry
    #   Amount.registry.locked?
    #   # => false
    def registry
      Amount.instance_variable_get(:@registry) ||
        replace_registry(Registry.new)
    end

    # @param symbol [Symbol, String]
    # @param opts [Hash]
    # @return [void]
    # @example Registering a type
    #   Amount.register :USDC,
    #     decimals: 6,
    #     display_symbol: "$",
    #     display_position: :prefix,
    #     ui_decimals: 2
    def register(symbol, **opts)
      registry.register(symbol, **opts)
    end

    # @param from [Symbol, String]
    # @param to [Symbol, String]
    # @param rate [String, Numeric, BigDecimal]
    # @return [void]
    # @example Registering a directional default rate
    #   Amount.register_default_rate :USD, :USDC, "1"
    def register_default_rate(from, to, rate)
      registry.register_default_rate(from, to, rate)
    end

    # Parses the compact client-facing string representation.
    #
    # Accepts either the default form `SYMBOL|amount` or the explicit versioned
    # form `v1:SYMBOL|amount`.
    #
    # @param str [String]
    # @return [Amount]
    # @raise [InvalidInput]
    # @example Parsing the default compact format
    #   Amount.parse("USDC|1.50")
    #
    # @example Parsing the explicit versioned compact format
    #   Amount.parse("v1:USDC|1.50")
    def parse(str)
      Parser.new(str).parse
    end

    # When called as `Amount.new` for a symbol whose registry entry binds a
    # custom class, dispatch the construction to that class instead of raising.
    # Direct calls to a subclass (`GoldAmount.new(...)`) still go through the
    # default `Class.new` path. Calls that target the wrong subclass continue
    # to raise from `#initialize`.
    #
    # @param value [Integer, String, Float, BigDecimal, Rational]
    # @param symbol [Symbol, String]
    # @param from [Symbol, nil]
    # @return [Amount]
    def new(value, symbol, from: nil)
      if equal?(::Amount)
        entry_class = registry.lookup(symbol.to_sym).amount_class
        return entry_class.new(value, symbol, from:) if entry_class && entry_class != ::Amount
      end
      super
    end

    # Coerces a numeric input to BigDecimal in a way that preserves Rational
    # values. `BigDecimal(value.to_s)` raises `ArgumentError` for Rational
    # because `Rational#to_s` produces strings like `"3/2"`. This helper is
    # the single place every call site should use to convert a scalar / rate /
    # display-unit scale into a BigDecimal.
    #
    # @param value [Numeric, BigDecimal, Rational, String]
    # @return [BigDecimal]
    def coerce_decimal(value)
      case value
      when BigDecimal then value
      when Rational then BigDecimal(value, Float::DIG + 4)
      else BigDecimal(value.to_s)
      end
    end

    # Temporarily swaps the global registry. Intended for tests.
    #
    # @param registry [Amount::Registry]
    # @yield
    # @return [Object]
    # @example Using a temporary registry
    #   test_registry = Amount::Registry.new
    #   Amount.with_registry(test_registry) do
    #     Amount.register :TEST, decimals: 2
    #   end
    def with_registry(registry)
      original = Amount.instance_variable_get(:@registry)
      replace_registry(registry)
      yield
    ensure
      replace_registry(original)
    end

    private

    def replace_registry(registry)
      current = Amount.instance_variable_get(:@registry)
      current&.remove_generated_methods!
      Amount.instance_variable_set(:@registry, registry)
      registry&.activate_generated_methods!
      registry
    end
  end

  attr_reader :atomic, :symbol, :display

  # Creates an amount for a registered symbol.
  #
  # Input inference rules:
  # - `Integer` => atomic units
  # - `String` => UI decimal value
  # - `Float`, `BigDecimal`, `Rational` => UI decimal value
  # - `from:` overrides inference explicitly
  #
  # @param value [Integer, String, Float, BigDecimal, Rational]
  # @param symbol [Symbol, String] registered type identifier
  # @param from [Symbol, nil] one of `:atomic`, `:ui`, or `:float`
  # @raise [Amount::Registry::UnknownType] if the symbol is not registered
  # @raise [InvalidInput] if the value cannot be interpreted for the symbol
  # @example Integer inputs are atomic by default
  #   Amount.new(1_500_000, :USDC).decimal.to_s("F")
  #   # => "1.5"
  #
  # @example String inputs are UI values by default
  #   Amount.new("1.50", :USDC).atomic
  #   # => 1500000
  def initialize(value, symbol, from: nil)
    @symbol = symbol.to_sym
    @entry = self.class.registry.lookup(@symbol)

    expected = @entry.amount_class
    if expected && expected != Amount && self.class != Amount && !instance_of?(expected)
      raise InvalidInput, "use #{expected}.new for #{@symbol}"
    end

    @atomic = infer_value(from, value)
    @display = Display.new(self)
  end

  include Arithmetic
  include Allocation
  include Comparison
  include Conversion
  include Serialization

  # @return [Amount::Registry::Entry]
  # @example Accessing display configuration for this amount
  #   Amount.usdc("1").registry_entry.ui_decimals
  #   # => 2
  def registry_entry
    @entry
  end

  # @return [Integer]
  # @example Reading the registered storage precision
  #   Amount.usdc("1").decimals
  #   # => 6
  def decimals
    @entry.decimals
  end

  # @return [BigDecimal]
  # @example Converting the atomic value back to a decimal quantity
  #   Amount.usdc(1_500_000, from: :atomic).decimal.to_s("F")
  #   # => "1.5"
  def decimal
    BigDecimal(@atomic) / (BigDecimal(10)**decimals)
  end

  def_delegators :display, :formatted, :ui, :to_s, :in_unit

  # @return [String]
  # @example Console-friendly inspection
  #   Amount.usdc("1.50").inspect
  #   # => "#<Amount USDC $1.50>"
  def inspect
    "#<#{self.class} #{symbol} #{ui}>"
  end

  private

  # Builds a same-symbol amount in the receiver's class. Used by every
  # operator that returns an Amount so subclass identity propagates.
  def build(atomic_value)
    self.class.new(atomic_value, symbol, from: :atomic)
  end

  def ensure_same_type!(other)
    return if same_type?(other)

    raise TypeMismatch, "type mismatch: #{symbol} vs #{other.is_a?(Amount) ? other.symbol : other.class}"
  end

  def coerce_other_to_self_type(other)
    return other if same_type?(other)
    return unless other.is_a?(Amount)

    other.to(symbol)
  rescue Registry::NoDefaultRate
    nil
  end

  def coerce_other_to_self_type!(other)
    coerce_other_to_self_type(other) || raise(
      TypeMismatch,
      "type mismatch: #{symbol} vs #{other.is_a?(Amount) ? other.symbol : other.class}"
    )
  end

  def infer_value(from, value)
    case from || infer_type(value)
    when :atomic then value.to_i
    when :ui then ui_to_atomic(value)
    when :float then ui_to_atomic(value.is_a?(Rational) ? value : value.to_s)
    else
      raise InvalidInput, "unknown amount format: #{value.inspect}"
    end
  end

  def infer_type(value)
    case value
    when Integer then :atomic
    when String then :ui
    when Float, BigDecimal, Rational then :float
    else
      raise InvalidInput, "cannot infer type for #{value.class}"
    end
  end

  def ui_to_atomic(value)
    return (value * (10**decimals)).to_i if value.is_a?(Rational)

    (BigDecimal(value.to_s) * (BigDecimal(10)**decimals)).to_i
  rescue ArgumentError
    raise InvalidInput, "cannot parse #{value.inspect} as #{symbol}"
  end
end
