# frozen_string_literal: true

require "bigdecimal"
require "forwardable"

# Every core file loads from here, in dependency order; core files don't
# require each other. The optional adapters (amount/active_record,
# amount/rspec) are separate entry points that load their own files.
require_relative "amount/version"
require_relative "amount/registry"
require_relative "amount/registry/generated_constructors"
require_relative "amount/locale"
require_relative "amount/compact"
require_relative "amount/display"
require_relative "amount/parser"
require_relative "amount/ui_parser"

# Concerns: modules mixed into Amount. Files live in amount/concerns/, but the
# constants are Amount::<Name> (the folder is not a namespace).
require_relative "amount/concerns/registrable"
require_relative "amount/concerns/localizable"
require_relative "amount/concerns/parsable"
require_relative "amount/concerns/constructible"
require_relative "amount/concerns/coercible"
require_relative "amount/concerns/calculable"
require_relative "amount/concerns/allocatable"
require_relative "amount/concerns/orderable"
require_relative "amount/concerns/convertible"
require_relative "amount/concerns/serializable"
require_relative "amount/concerns/formattable"

# Represents a precise quantity of a registered fungible type.
#
# `Amount` stores its value as an arbitrary-precision atomic `Integer` in the
# smallest unit configured for the registered symbol. UI values are parsed from
# strings or decimals, while integer inputs are treated as atomic counts unless
# `from:` overrides inference.
#
# This class holds only an amount's identity: its atomic value, its symbol and
# registry entry, and the decimal view of the value. Everything else comes
# from concerns:
# - {Registrable}  — `Amount.registry`, `register`, `register_default_rate`,
#   `with_registry`
# - {Localizable}  — `Amount.localize`
# - {Parsable}       — `Amount.parse`, `Amount.parse_ui`
# - {Constructible}  — input inference, `Amount.new` dispatch to a registered
#   subclass, `build`
# - {Coercible}      — `Amount.coerce_decimal`, cross-type operand coercion
# - {Calculable}    — `+`, `-`, `*`, `/`, `abs`, `-@`
# - {Orderable}    — `<=>`, `==`, `eql?`, `hash`, `same_type?`, sign predicates
# - {Convertible}    — `to(:SYMBOL, rate:)`
# - {Allocatable}    — `split(n)`, `allocate(weights)`
# - {Serializable} — `to_h`, `as_json`, `Amount.load`
# - {Formattable}   — `display_format(unit:, locale:)`, where the number and
#   unit go
#
# New behavior belongs in a concern, not in this class. See
# `.claude/rules/concerns.md` for the shape a concern takes.
#
# @example Constructing from a UI value
#   Amount.register :USDC, decimals: 6
#
#   Amount.of_usdc("1.50").atomic
#   # => 1500000
#
# @example Constructing from an atomic value
#   Amount.of_usdc(1_500_000, from: :atomic).decimal.to_s("F")
#   # => "1.5"
class Amount
  include Registrable
  include Localizable
  include Parsable
  include Constructible
  include Coercible
  include Calculable
  include Allocatable
  include Orderable
  include Convertible
  include Serializable
  include Formattable

  extend Forwardable

  class Error < StandardError; end
  class TypeMismatch < Error; end
  class InvalidInput < Error; end
  class UnregisteredType < Error; end

  attr_reader :atomic, :symbol, :display

  # Creates an amount for a registered symbol.
  #
  # See {Constructible} for how `value` is read.
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
    ensure_registered_class!
    @atomic = infer_value(from, value)
    @display = Display.new(self)
  end

  # @return [Amount::Registry::Entry]
  # @example Accessing display configuration for this amount
  #   Amount.of_usdc("1").registry_entry.ui_decimals
  #   # => 2
  def registry_entry
    @entry
  end

  # @return [Integer]
  # @example Reading the registered storage precision
  #   Amount.of_usdc("1").decimals
  #   # => 6
  def decimals
    @entry.decimals
  end

  # @return [BigDecimal]
  # @example Converting the atomic value back to a decimal quantity
  #   Amount.of_usdc(1_500_000, from: :atomic).decimal.to_s("F")
  #   # => "1.5"
  def decimal
    BigDecimal(@atomic) / (BigDecimal(10)**decimals)
  end

  def_delegators :display, :formatted, :ui, :unit_label, :to_s, :in_unit

  # @return [String]
  # @example Console-friendly inspection
  #   Amount.of_usdc("1.50").inspect
  #   # => "#<Amount USDC $1.50>"
  def inspect
    "#<#{self.class} #{symbol} #{ui}>"
  end
end
