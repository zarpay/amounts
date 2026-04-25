# frozen_string_literal: true

class Amount
  # Versioned hash serialization. Pairs with the class-level `Amount.parse`
  # (compact-string form) and `Amount.load` (versioned-hash form).
  module Serialization
    # @return [Hash]
    # @example
    #   Amount.usdc("1.50").to_h
    #   # => { v: 1, atomic: "1500000", symbol: "USDC" }
    def to_h
      Serializer.dump(self)
    end
  end
end
