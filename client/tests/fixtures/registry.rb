# frozen_string_literal: true

# The registry and translations the client's tests run against. The client
# never reads this file: `export-manifest.rb` exports it through the gem
# into `manifest.json`, and every expected value in the tests is what the
# gem produces for this registry.
#
# Load it from gem/ so the gem under development is the one exporting:
#
#   cd gem && bundle exec ruby -Ilib ../client/tests/fixtures/export-manifest.rb

require "i18n"
require "amounts"

I18n.available_locales = %i[en de fr]
I18n.backend.store_translations(:en, number: { format: { delimiter: ",", separator: "." } })
I18n.backend.store_translations(
  :de,
  number: {
    format: { delimiter: ".", separator: "," },
    human: { decimal_units: { format: "%n %u", units: { thousand: "Tsd.", million: { one: "Million", other: "Millionen" } } } }
  },
  amounts: {
    units: { gold: "Feinunze", searches: { one: "Suche", other: "Suchen" } },
    formats: { eur: "%n %u" },
    display_units: { gold: { gram: "Gramm" } },
    display_unit_formats: { gold: { kg: "%n %u" } }
  }
)
I18n.backend.store_translations(:fr, number: { format: { delimiter: " ", separator: "," } })

Amount.register :USDC, decimals: 6, display_symbol: "$", display_position: :prefix, ui_decimals: 2
Amount.register :USD, decimals: 2, display_symbol: "$", display_position: :prefix, ui_decimals: 2
Amount.register :SOL, decimals: 9, display_symbol: "SOL", ui_decimals: 4, trim_zeros: true
Amount.register :GOLD, decimals: 8, display_symbol: "oz t", ui_decimals: 4, default_display: :oz_t,
                       display_units: {
                         oz_t: { scale: 1, ui_decimals: 4 },
                         gram: { scale: "31.1034768", symbol: "g", ui_decimals: 2 },
                         kg: { scale: "0.0311034768", symbol: "kg", ui_decimals: 5, trim_zeros: true },
                         grain: { scale: 480, symbol: "gr", ui_decimals: 0, position: :prefix }
                       }
Amount.register :LOGS, decimals: 0, display_symbol: "logs"
Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search", other: "searches" }
Amount.register :EUR, decimals: 2, display_symbol: "€", display_format: "%u%n"
Amount.register :TOKENS, decimals: 0, display_symbol: "TOKENS"
Amount.register :ETH, decimals: 18, display_symbol: "ETH", ui_decimals: 4
Amount.register :BARE, decimals: 2, display_symbol: ""

Amount.register_default_rate :USD, :USDC, "1"
Amount.register_default_rate :USDC, :USD, "1"
Amount.register_default_rate :USDC, :SOL, "0.0066666666"
Amount.register_default_rate :USDC, :EUR, Rational(1, 3)
