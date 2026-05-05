# frozen_string_literal: true

class Amount
  # Arithmetic operators for `Amount`. Mixed into `Amount` and inherited by
  # any registered subclass.
  #
  # All operators preserve the receiver's class via `build`, so subclass
  # identity (`GoldAmount`) survives through `+`, `-`, `*`, `/`, `abs`, `-@`.
  module Arithmetic
    # @return [Amount]
    # @example
    #   Amount.of_usdc("-1").abs
    #   # => #<Amount USDC $1.00>
    def abs
      build(@atomic.abs)
    end

    # @return [Amount]
    # @example
    #   -Amount.of_usdc("1")
    #   # => #<Amount USDC -$1.00>
    def -@
      build(-@atomic)
    end

    # @param other [Amount]
    # @return [Amount]
    # @raise [TypeMismatch]
    # @example Same-type addition
    #   Amount.of_usdc("1.50") + Amount.of_usdc("0.50")
    #
    # @example Cross-type addition using a registered directional rate
    #   Amount.register_default_rate :USD, :USDC, "1"
    #   Amount.of_usdc("10.00") + Amount.new("5.00", :USD)
    def +(other)
      rhs = coerce_other_to_self_type!(other)
      build(@atomic + rhs.atomic)
    end

    # @param other [Amount]
    # @return [Amount]
    # @raise [TypeMismatch]
    # @example
    #   Amount.of_usdc("2.00") - Amount.of_usdc("0.50")
    def -(other)
      rhs = coerce_other_to_self_type!(other)
      build(@atomic - rhs.atomic)
    end

    # @param scalar [Numeric]
    # @return [Amount]
    # @raise [TypeMismatch]
    # @example
    #   Amount.of_usdc("1.25") * 2
    def *(scalar)
      ensure_scalar!(scalar)
      build((BigDecimal(@atomic) * Amount.coerce_decimal(scalar)).to_i)
    end

    # @param other [Amount, Numeric]
    # @return [Amount, BigDecimal]
    # @raise [TypeMismatch, ZeroDivisionError]
    # @example Dividing by a scalar returns an amount
    #   Amount.of_usdc("1.00") / 2
    #
    # @example Dividing by an amount returns a ratio
    #   Amount.of_usdc("10.00") / Amount.of_usdc("2.00")
    def /(other)
      if other.is_a?(Amount)
        ensure_same_type!(other)
        raise ZeroDivisionError if other.zero?

        BigDecimal(@atomic) / BigDecimal(other.atomic)
      else
        ensure_scalar!(other)
        raise ZeroDivisionError if other.zero?

        build((BigDecimal(@atomic) / Amount.coerce_decimal(other)).to_i)
      end
    end

    private

    def ensure_scalar!(value)
      return if value.is_a?(Integer) || value.is_a?(Float) ||
                value.is_a?(BigDecimal) || value.is_a?(Rational)

      raise TypeMismatch, "expected scalar, got #{value.class}"
    end
  end
end
