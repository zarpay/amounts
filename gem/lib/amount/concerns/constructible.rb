# frozen_string_literal: true

require "bigdecimal"

class Amount
  # Concern: how a constructor input becomes an atomic `Integer`, and which
  # class an amount is built as.
  #
  # Input inference rules:
  # - `Integer` => atomic units
  # - `String` => UI decimal value
  # - `Float`, `BigDecimal`, `Rational` => UI decimal value (a `Float` goes
  #   through its string form, never through float math)
  # - `from:` (`:atomic`, `:ui`, `:float`) overrides inference
  #
  # Class identity: a type registered with `class:` is always built as that
  # class. `Amount.new` dispatches to it, and every operator that returns an
  # amount goes through {#build} so the receiver's class carries through.
  module Constructible
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does
    # `include Constructible`.
    module ClassMethods
      # When called as `Amount.new` for a symbol whose registry entry binds a
      # custom class, dispatch the construction to that class instead of
      # raising. Direct calls to a subclass (`GoldAmount.new(...)`) still go
      # through the default `Class.new` path. Calls that target the wrong
      # subclass continue to raise from `#initialize`.
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
    end

    private

    # Builds a same-symbol amount in the receiver's class. Used by every
    # operator that returns an Amount so subclass identity propagates.
    def build(atomic_value)
      self.class.new(atomic_value, symbol, from: :atomic)
    end

    # A type registered with `class: GoldAmount` must be built as
    # `GoldAmount` (or dispatched there by `Amount.new`), never as another
    # subclass.
    def ensure_registered_class!
      expected = registry_entry.amount_class
      return unless expected && expected != Amount && self.class != Amount && !instance_of?(expected)

      raise InvalidInput, "use #{expected}.new for #{symbol}"
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
end
