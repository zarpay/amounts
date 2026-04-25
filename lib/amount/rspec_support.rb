# frozen_string_literal: true

class Amount
  # Shared coercion helpers for opt-in RSpec integrations.
  module RSpecSupport
    module_function

    def coerce_amount_arguments(arguments)
      case arguments.length
      when 1
        coerce_amount(arguments.first)
      when 2
        Amount.new(arguments.last, arguments.first)
      else
        raise ArgumentError, "expected an Amount, a parse string, or a symbol/value pair"
      end
    end

    def coerce_amount(value)
      case value
      when Amount then value
      when String then Amount.parse(value)
      when Hash then Amount.load(value)
      else
        raise ArgumentError, "cannot coerce #{value.inspect} into an Amount"
      end
    end

    def coerce_delta(expected_amount, within)
      case within
      when Amount
        within
      when Integer, Float, BigDecimal, Rational, String
        Amount.new(within, expected_amount.symbol)
      else
        raise ArgumentError, "cannot coerce #{within.inspect} into an amount delta"
      end
    end

    def normalize_amount_sums(sum_hash)
      sum_hash.to_h do |symbol, atomic|
        amount = Amount.new(atomic, symbol, from: :atomic)
        [amount.symbol, amount]
      end
    end
  end
end
