# frozen_string_literal: true

class Amount
  # Cross-type conversion via `to(target_symbol, rate:)`. Uses an explicitly
  # passed rate when provided, otherwise looks up the registered directional
  # default rate. The result class is taken from the target symbol's registry
  # entry, so a `class:`-registered subclass becomes the natural identity for
  # conversion outputs.
  module Conversion
    # @param target_symbol [Symbol, String]
    # @param rate [String, Numeric, BigDecimal, nil]
    # @return [Amount]
    # @raise [Amount::Registry::NoDefaultRate] if no explicit or registered rate is available
    # @example Using an explicit one-off rate
    #   Amount.of_usdc("100").to(:GOLD, rate: "0.00042")
    #
    # @example Using a registered default rate
    #   Amount.register_default_rate :USDC, :USD, "1"
    #   Amount.of_usdc("1.50").to(:USD)
    def to(target_symbol, rate: nil)
      target_symbol = target_symbol.to_sym
      return self.class.new(@atomic, symbol, from: :atomic) if target_symbol == symbol

      rate = resolve_rate(target_symbol, rate)
      target_entry = self.class.registry.lookup(target_symbol)

      decimal_result = decimal * Amount.coerce_decimal(rate)
      atomic_result = (decimal_result * (BigDecimal(10)**target_entry.decimals)).to_i

      target_entry.amount_class.new(atomic_result, target_symbol, from: :atomic)
    end

    private

    def resolve_rate(target, provided)
      return provided if provided

      self.class.registry.default_rate(symbol, target)
    end
  end
end
