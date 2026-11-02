# frozen_string_literal: true

class Amount
  # Comparison, equality, hashing, and sign predicates for `Amount`.
  #
  # Pulls in `Comparable` itself so consumers only need `include Comparison`
  # to get `<`, `<=`, `>`, `>=`, `between?`, `clamp`, and `Enumerable#min`/
  # `#max` alongside the explicit `<=>` / `==` / `eql?` / `hash` defined here.
  module Comparison
    include Comparable
    # @param other [Object]
    # @return [Boolean]
    # @example
    #   Amount.of_usdc("1").same_type?(Amount.of_usdc("2"))
    #   # => true
    def same_type?(other)
      other.is_a?(Amount) && other.symbol == symbol
    end

    # @return [Boolean]
    # @example
    #   Amount.of_usdc(0, from: :atomic).zero?
    #   # => true
    def zero? = @atomic.zero?

    # @return [Boolean]
    # @example
    #   Amount.of_usdc("1").positive?
    #   # => true
    def positive? = @atomic.positive?

    # @return [Boolean]
    # @example
    #   Amount.of_usdc("-1").negative?
    #   # => true
    def negative? = @atomic.negative?

    # @param other [Object]
    # @return [-1, 0, 1, nil]
    # @example
    #   Amount.of_usdc("1") <=> Amount.of_usdc("2")
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
    #   Amount.of_usdc("1.50") == Amount.of_usdc("1.50")
    #   # => true
    def ==(other)
      same_type?(other) && @atomic == other.atomic
    end

    # @param other [Object]
    # @return [Boolean]
    # @example Hash-key equality keeps class and symbol identity
    #   Amount.of_usdc("1").eql?(Amount.of_usdc("1"))
    #   # => true
    def eql?(other)
      other.class == self.class && symbol == other.symbol && @atomic == other.atomic
    end

    # @return [Integer]
    # @example
    #   { Amount.of_usdc("1") => :ok }[Amount.of_usdc("1")]
    #   # => :ok
    def hash
      [self.class, symbol, @atomic].hash
    end
  end
end
