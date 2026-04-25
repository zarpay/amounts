# Changelog

## 0.0.2 - 2026-04-26

### Fixed

- `Amount.new(value, symbol)` now dispatches to the registered subclass when the
  symbol was registered with `class:`, so `Amount.parse`, `Amount.load`, and the
  ActiveRecord adapter (`Type#cast`, `Type#deserialize`) construct the correct
  type instead of raising `InvalidInput`. The previous behavior made it
  impossible to read a custom-class amount back out of an ActiveRecord column.
  The strict-mode error is preserved for explicit wrong-subclass usage
  (`OtherSubclass.new(value, :GOLD)`).
- `Rational` UI input is now accepted as documented. Previously
  `Amount.new(Rational(3, 2), :USDC)` raised because the value was stringified
  into `"3/2"` before reaching `BigDecimal()`. Rational input is now converted
  via integer math (`(rational * 10**decimals).to_i`), giving exact results for
  finite fractions and well-defined truncate-toward-zero behavior for
  repeating fractions.
- `AmountValidator` thresholds for multi-symbol `has_amount` attributes accept
  raw numerics. `validates :amount, amount: { greater_than: 0 }` now means
  "greater than zero in the value's symbol" instead of producing
  `"has invalid greater_than constraint: raw numeric assignment requires a
  fixed symbol"`. Fixed-symbol attributes are unchanged.

## 0.0.1 - 2026-04-25

- Initial release.
- Added the `Amount` core value object with atomic integer storage.
- Added directional default-rate conversion for cross-type arithmetic and comparison.
- Added explicit `[parts, remainder]` semantics for `split` and `allocate`.
- Added optional ActiveRecord integration via `require "amount/active_record"`.
