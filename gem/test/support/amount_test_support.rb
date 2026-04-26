# frozen_string_literal: true

require "bigdecimal"
require_relative "../../lib/amount"

module AmountTestSupport
  module_function

  def register_default_types!
    Amount.registry.clear!
    Amount.register :USDC, decimals: 6, display_symbol: "$",
                    display_position: :prefix, ui_decimals: 2
    Amount.register :USD, decimals: 2, display_symbol: "$",
                    display_position: :prefix, ui_decimals: 2
    Amount.register :SOL, decimals: 9, display_symbol: "SOL",
                    display_position: :suffix, ui_decimals: 4
    Amount.register :GOLD, decimals: 8, display_symbol: "oz t",
                     display_position: :suffix, ui_decimals: 4,
                     display_units: {
                       oz_t: { scale: 1, symbol: "oz t", ui_decimals: 4 },
                       gram: { scale: "31.1035", symbol: "g", ui_decimals: 2 },
                       kg: { scale: "0.0311035", symbol: "kg", ui_decimals: 5 }
                     },
                     default_display: :oz_t
    Amount.register :LOGS, decimals: 0, display_symbol: "logs",
                    display_position: :suffix, ui_decimals: 0
  end

  def register_active_record_types!
    Amount.registry.clear!
    Amount.register :USDC, decimals: 6, display_symbol: "$",
                    display_position: :prefix, ui_decimals: 2
    Amount.register :USD, decimals: 2, display_symbol: "$",
                    display_position: :prefix, ui_decimals: 2
    Amount.register :SOL, decimals: 9, display_symbol: "SOL",
                    display_position: :suffix, ui_decimals: 4
  end
end
