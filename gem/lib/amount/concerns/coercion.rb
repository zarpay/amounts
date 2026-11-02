# frozen_string_literal: true

require "bigdecimal"

class Amount
  # Concern: bringing the other side of an operation into a usable form.
  #
  # - {ClassMethods#coerce_decimal} turns a scalar, rate or display-unit scale
  #   into a `BigDecimal` without losing a `Rational`.
  # - The private instance helpers bring another amount to the receiver's
  #   type. They only cross types through a registered directional default
  #   rate; without one they raise {TypeMismatch} (or return `nil` for
  #   comparisons). There is no implicit conversion.
  module Coercion
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level methods extended onto any class that does `include Coercion`.
    module ClassMethods
      # Coerces a numeric input to BigDecimal in a way that preserves Rational
      # values. `BigDecimal(value.to_s)` raises `ArgumentError` for Rational
      # because `Rational#to_s` produces strings like `"3/2"`. This helper is
      # the single place every call site should use to convert a scalar / rate
      # / display-unit scale into a BigDecimal.
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
    end

    private

    def ensure_same_type!(other)
      return if same_type?(other)

      raise TypeMismatch, type_mismatch_message(other)
    end

    # The other amount in the receiver's type: itself when the types match,
    # converted through a registered default rate when one exists, else `nil`.
    def coerce_other_to_self_type(other)
      return other if same_type?(other)
      return unless other.is_a?(Amount)

      other.to(symbol)
    rescue Registry::NoDefaultRate
      nil
    end

    def coerce_other_to_self_type!(other)
      coerce_other_to_self_type(other) || raise(TypeMismatch, type_mismatch_message(other))
    end

    def type_mismatch_message(other)
      "type mismatch: #{symbol} vs #{other.is_a?(Amount) ? other.symbol : other.class}"
    end
  end
end
