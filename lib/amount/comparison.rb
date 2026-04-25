# frozen_string_literal: true

class Amount
  # Comparison, equality, hashing, and sign predicates for `Amount`.
  #
  # `<=>` is defined here, which together with `Comparable` (mixed in on the
  # main `Amount` class) gives `<`, `<=`, `>`, `>=`, `between?`, and
  # `Enumerable#min`/`#max` for free.
  module Comparison
    # @param other [Object]
    # @return [Boolean]
    # @example
    #   Amount.usdc("1").same_type?(Amount.usdc("2"))
    #   # => true
    def same_type?(other)
      other.is_a?(Amount) && other.symbol == symbol
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
  end
end
