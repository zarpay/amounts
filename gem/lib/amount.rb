# frozen_string_literal: true

require "bigdecimal"
require "forwardable"

require_relative "amount/version"
require_relative "amount/registry"
require_relative "amount/locale"
require_relative "amount/compact"
require_relative "amount/display"
require_relative "amount/parser"
require_relative "amount/ui_parser"

# Concerns: modules mixed into Amount. Files live in amount/concerns/, but the
# constants are Amount::<Name> (the folder is not a namespace).
require_relative "amount/concerns/registration"
require_relative "amount/concerns/localization"
require_relative "amount/concerns/parsing"
require_relative "amount/concerns/construction"
require_relative "amount/concerns/coercion"
require_relative "amount/concerns/arithmetic"
require_relative "amount/concerns/allocation"
require_relative "amount/concerns/comparison"
require_relative "amount/concerns/conversion"
require_relative "amount/concerns/serialization"
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
# - {Registration}  — `Amount.registry`, `register`, `register_default_rate`,
#   `with_registry`
# - {Localization}  — `Amount.localize`
# - {Parsing}       — `Amount.parse`, `Amount.parse_ui`
# - {Construction}  — input inference, `Amount.new` dispatch to a registered
#   subclass, `build`
# - {Coercion}      — `Amount.coerce_decimal`, cross-type operand coercion
# - {Arithmetic}    — `+`, `-`, `*`, `/`, `abs`, `-@`
# - {Comparison}    — `<=>`, `==`, `eql?`, `hash`, `same_type?`, sign predicates
# - {Conversion}    — `to(:SYMBOL, rate:)`
# - {Allocation}    — `split(n)`, `allocate(weights)`
# - {Serialization} — `to_h`, `as_json`, `Amount.load`
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
  include Registration
  include Localization
  include Parsing
  include Construction
  include Coercion
  include Arithmetic
  include Allocation
  include Comparison
  include Conversion
  include Serialization
  include Formattable

  extend Forwardable

  class Error < StandardError; end
  class TypeMismatch < Error; end
  class InvalidInput < Error; end
  class UnregisteredType < Error; end

  attr_reader :atomic, :symbol, :display

  # Creates an amount for a registered symbol.
  #
  # See {Construction} for how `value` is read.
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
