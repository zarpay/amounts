# frozen_string_literal: true

class Amount
  # Splitting and proportional allocation. Both operations return
  # `[parts, remainder]`, preserving the invariant that the parts plus
  # remainder always sum back to the receiver's atomic value (including
  # the sign).
  module Allocation
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

    private

    def atomic_sign
      return 1 if @atomic.positive?
      return(-1) if @atomic.negative?

      0
    end
  end
end
