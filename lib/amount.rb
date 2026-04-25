# frozen_string_literal: true

require "bigdecimal"
require "forwardable"

require_relative "amount/version"
require_relative "amount/registry"
require_relative "amount/display"
require_relative "amount/parser"
require_relative "amount/serializer"

# Represents a precise quantity of a registered fungible type.
#
# `Amount` stores its value as an arbitrary-precision atomic `Integer` in the
# smallest unit configured for the registered symbol. UI values are parsed from
# strings or decimals, while integer inputs are treated as atomic counts unless
# `from:` overrides inference.
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

  attr_reader :atomic, :symbol

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
  end

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

  # @return [Amount::Display]
  # @example Delegating formatting concerns
  #   Amount.usdc("1.50").display.ui
  #   # => "$1.50"
  def display
    @display ||= Display.new(self)
  end

  def_delegators :display, :formatted, :ui, :to_s, :in_unit

  # @return [String]
  # @example Console-friendly inspection
  #   Amount.usdc("1.50").inspect
  #   # => "#<Amount USDC $1.50>"
  def inspect
    "#<#{self.class} #{symbol} #{ui}>"
  end

  # @return [Boolean]
  # @example
  #   Amount.usdc(0, from: :atomic).zero?
  #   # => true
  def zero? = @atomic.zero?

  # @return [Boolean]
  # @example
  #   Amount.usdc("1").positive?
  #   # => true
  def positive? = @atomic.positive?

  # @return [Boolean]
  # @example
  #   Amount.usdc("-1").negative?
  #   # => true
  def negative? = @atomic.negative?

  # @param other [Object]
  # @return [Boolean]
  # @example
  #   Amount.usdc("1").same_type?(Amount.usdc("2"))
  #   # => true
  def same_type?(other)
    other.is_a?(Amount) && other.symbol == symbol
  end

  # @return [Amount]
  # @example
  #   Amount.usdc("-1").abs
  #   # => #<Amount USDC $1.00>
  def abs
    build(@atomic.abs)
  end

  # @return [Amount]
  # @example
  #   -Amount.usdc("1")
  #   # => #<Amount USDC -$1.00>
  def -@
    build(-@atomic)
  end

  # @param other [Amount]
  # @return [Amount]
  # @raise [TypeMismatch]
  # @example Same-type addition
  #   Amount.usdc("1.50") + Amount.usdc("0.50")
  #
  # @example Cross-type addition using a registered directional rate
  #   Amount.register_default_rate :USD, :USDC, "1"
  #   Amount.usdc("10.00") + Amount.new("5.00", :USD)
  def +(other)
    rhs = coerce_other_to_self_type!(other)
    build(@atomic + rhs.atomic)
  end

  # @param other [Amount]
  # @return [Amount]
  # @raise [TypeMismatch]
  # @example
  #   Amount.usdc("2.00") - Amount.usdc("0.50")
  def -(other)
    rhs = coerce_other_to_self_type!(other)
    build(@atomic - rhs.atomic)
  end

  # @param scalar [Numeric]
  # @return [Amount]
  # @raise [TypeMismatch]
  # @example
  #   Amount.usdc("1.25") * 2
  def *(scalar)
    ensure_scalar!(scalar)
    build((BigDecimal(@atomic) * BigDecimal(scalar.to_s)).to_i)
  end

  # @param other [Amount, Numeric]
  # @return [Amount, BigDecimal]
  # @raise [TypeMismatch, ZeroDivisionError]
  # @example Dividing by a scalar returns an amount
  #   Amount.usdc("1.00") / 2
  #
  # @example Dividing by an amount returns a ratio
  #   Amount.usdc("10.00") / Amount.usdc("2.00")
  def /(other)
    if other.is_a?(Amount)
      ensure_same_type!(other)
      raise ZeroDivisionError if other.zero?

      BigDecimal(@atomic) / BigDecimal(other.atomic)
    else
      ensure_scalar!(other)
      raise ZeroDivisionError if other.zero?

      build((BigDecimal(@atomic) / BigDecimal(other.to_s)).to_i)
    end
  end

  # Splits into equal parts and returns the leftover explicitly.
  #
  # @param n [Integer]
  # @return [Array<(Array<Amount>, Amount)>]
  # @raise [ArgumentError] if `n` is not a positive integer
  # @example
  #   parts, remainder = Amount.new(10, :LOGS).split(3)
  #   parts.map(&:atomic)
  #   # => [3, 3, 3]
  #   remainder.atomic
  #   # => 1
  def split(n)
    raise ArgumentError, "n must be positive" unless n.is_a?(Integer) && n.positive?

    sign = atomic_sign
    base, remainder = @atomic.abs.divmod(n)
    parts = Array.new(n) { build(sign * base) }

    [parts, build(sign * remainder)]
  end

  # Allocates proportionally by integer weights and returns the leftover explicitly.
  #
  # @param weights [Array<Integer>]
  # @return [Array<(Array<Amount>, Amount)>]
  # @raise [ArgumentError] if weights are empty, negative, or sum to zero
  # @example
  #   parts, remainder = Amount.new(10, :LOGS).allocate([1, 1, 2])
  #   parts.map(&:atomic)
  #   # => [2, 2, 5]
  #   remainder.atomic
  #   # => 1
  def allocate(weights)
    raise ArgumentError, "weights must be non-empty" if weights.empty?
    raise ArgumentError, "weights must be non-negative integers" unless weights.all? { |weight| weight.is_a?(Integer) && weight >= 0 }

    total = weights.sum
    raise ArgumentError, "weights must sum to positive value" unless total.positive?

    sign = atomic_sign
    absolute_atomic = @atomic.abs
    allocations = weights.map { |weight| absolute_atomic * weight / total }
    remainder = absolute_atomic - allocations.sum

    parts = allocations.map { |allocation| build(sign * allocation) }
    [parts, build(sign * remainder)]
  end

  # @param other [Object]
  # @return [-1, 0, 1, nil]
  # @example
  #   Amount.usdc("1") <=> Amount.usdc("2")
  #   # => -1
  def <=>(other)
    return nil unless other.is_a?(Amount)

    comparable = coerce_other_to_self_type(other)
    return nil unless comparable

    @atomic <=> comparable.atomic
  end

  # @param other [Object]
  # @return [Boolean]
  # @example
  #   Amount.usdc("1.50") == Amount.usdc("1.50")
  #   # => true
  def ==(other)
    same_type?(other) && @atomic == other.atomic
  end

  # @param other [Object]
  # @return [Boolean]
  # @example Hash-key equality keeps class and symbol identity
  #   Amount.usdc("1").eql?(Amount.usdc("1"))
  #   # => true
  def eql?(other)
    other.class == self.class && symbol == other.symbol && @atomic == other.atomic
  end

  # @return [Integer]
  # @example
  #   { Amount.usdc("1") => :ok }[Amount.usdc("1")]
  #   # => :ok
  def hash
    [self.class, symbol, @atomic].hash
  end

  # @param target_symbol [Symbol, String]
  # @param rate [String, Numeric, BigDecimal, nil]
  # @return [Amount]
  # @raise [Amount::Registry::NoDefaultRate] if no explicit or registered rate is available
  # @example Using an explicit one-off rate
  #   Amount.usdc("100").to(:GOLD, rate: "0.00042")
  #
  # @example Using a registered default rate
  #   Amount.register_default_rate :USDC, :USD, "1"
  #   Amount.usdc("1.50").to(:USD)
  def to(target_symbol, rate: nil)
    target_symbol = target_symbol.to_sym
    return self.class.new(@atomic, symbol, from: :atomic) if target_symbol == symbol

    rate = resolve_rate(target_symbol, rate)
    target_entry = self.class.registry.lookup(target_symbol)

    decimal_result = decimal * BigDecimal(rate.to_s)
    atomic_result = (decimal_result * (BigDecimal(10)**target_entry.decimals)).to_i

    target_entry.amount_class.new(atomic_result, target_symbol, from: :atomic)
  end

  # @return [Hash]
  # @example
  #   Amount.usdc("1.50").to_h
  #   # => { v: 1, atomic: "1500000", symbol: "USDC" }
  def to_h
    Serializer.dump(self)
  end

  # @param hash [Hash]
  # @return [Amount]
  # @raise [InvalidInput] for unsupported serialized versions
  # @example Loading the current versioned payload
  #   Amount.load(v: 1, atomic: "1500000", symbol: "USDC")
  #
  # @example Loading the legacy unversioned payload
  #   Amount.load(atomic: 1500000, symbol: :USDC)
  def self.load(hash)
    Serializer.load(hash)
  end

  private

  def build(atomic_value)
    self.class.new(atomic_value, symbol, from: :atomic)
  end

  def atomic_sign
    return 1 if @atomic.positive?
    return(-1) if @atomic.negative?

    0
  end

  def ensure_same_type!(other)
    return if same_type?(other)

    raise TypeMismatch, "type mismatch: #{symbol} vs #{other.is_a?(Amount) ? other.symbol : other.class}"
  end

  def ensure_scalar!(value)
    return if value.is_a?(Integer) || value.is_a?(Float) ||
              value.is_a?(BigDecimal) || value.is_a?(Rational)

    raise TypeMismatch, "expected scalar, got #{value.class}"
  end

  def resolve_rate(target, provided)
    return provided if provided

    self.class.registry.default_rate(symbol, target)
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

  def coerce_other_to_self_type!(other)
    coerce_other_to_self_type(other) || raise(
      TypeMismatch,
      "type mismatch: #{symbol} vs #{other.is_a?(Amount) ? other.symbol : other.class}"
    )
  end

  def coerce_other_to_self_type(other)
    return other if same_type?(other)
    return unless other.is_a?(Amount)

    other.to(symbol)
  rescue Registry::NoDefaultRate
    nil
  end
end
