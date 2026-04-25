# frozen_string_literal: true

class Amount
  module ActiveRecord
    # Casts user input into Amount objects for the optional ActiveRecord adapter.
    #
    # The type is intentionally explicit:
    # - strings are parsed using {Amount.parse}
    # - hashes are loaded or interpreted as value/symbol pairs
    # - raw numerics are only accepted for fixed-symbol attributes
    #
    # @example Casting a multi-symbol string value
    #   Amount::ActiveRecord::Type.new.cast("USDC|1.50")
    #
    # @example Casting a fixed-symbol numeric value
    #   Amount::ActiveRecord::Type.new(symbol: :SOL).cast(0.25)
    class Type
      attr_reader :fixed_symbol

      # @param symbol [Symbol, String, nil]
      # @example
      #   Amount::ActiveRecord::Type.new(symbol: :SOL)
      def initialize(symbol: nil)
        @fixed_symbol = symbol&.to_sym
      end

      # @param value [Amount, String, Hash, Numeric, nil]
      # @return [Amount, nil]
      # @raise [Amount::InvalidInput] when the value cannot be cast
      # @raise [Amount::TypeMismatch] when a fixed-symbol assignment uses a
      #   different symbol
      # @example
      #   type = Amount::ActiveRecord::Type.new
      #   type.cast("USDC|1.50")
      def cast(value)
        return nil if value.nil? || value == ""

        amount = case value
                 when ::Amount then value
                 when String then ::Amount.parse(value)
                 when Hash then cast_hash(value)
                 when Integer, Float, BigDecimal, Rational then cast_numeric(value)
                 else
                   raise ::Amount::InvalidInput, "cannot cast #{value.class} to Amount"
                 end

        ensure_fixed_symbol!(amount) if fixed_symbol
        amount
      end

      # @param atomic [Integer, String, BigDecimal]
      # @param symbol [Symbol, String, nil]
      # @return [Amount, nil]
      # @example
      #   Amount::ActiveRecord::Type.new.deserialize("1500000", :USDC)
      def deserialize(atomic, symbol = fixed_symbol)
        return nil if atomic.nil?

        resolved_symbol = (symbol || fixed_symbol)
        return nil if resolved_symbol.nil?

        ::Amount.new(atomic.to_i, resolved_symbol, from: :atomic)
      end

      # @param value [Amount, String, Hash, Numeric, nil]
      # @return [Hash, nil]
      # @example
      #   Amount::ActiveRecord::Type.new.dump("USDC|1.50")
      #   # => { atomic: 1500000, symbol: :USDC }
      def dump(value)
        amount = cast(value)
        return nil unless amount

        { atomic: amount.atomic, symbol: amount.symbol }
      end

      private

      def cast_hash(value)
        if value.key?(:atomic) || value.key?("atomic")
          ::Amount.load(value)
        else
          symbol = value.fetch(:symbol) { value.fetch("symbol", fixed_symbol) }
          amount_value = value.fetch(:value) { value.fetch("value") }
          ::Amount.new(amount_value, symbol)
        end
      rescue KeyError
        raise ::Amount::InvalidInput, "hash input must contain atomic/symbol or value/symbol"
      end

      def cast_numeric(value)
        unless fixed_symbol
          raise ::Amount::InvalidInput, "raw numeric assignment requires a fixed symbol"
        end

        ::Amount.new(value, fixed_symbol, from: :float)
      end

      def ensure_fixed_symbol!(amount)
        return if amount.symbol == fixed_symbol

        raise ::Amount::TypeMismatch, "expected #{fixed_symbol}, got #{amount.symbol}"
      end
    end
  end
end
