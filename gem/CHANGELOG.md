# Changelog

## 0.0.8 - 2026-05-05

### Changed

- **Breaking:** Generated constructors now have an `of_` prefix:
  `Amount.usdc("1.50")` becomes `Amount.of_usdc("1.50")`, `Amount.gold("1.0")`
  becomes `Amount.of_gold("1.0")`, and so on. Every generated constructor on
  `Amount` is renamed; only the registered symbol stays the same, so
  `Amount.new("1.50", :USDC)` still works.
- The original naming was a latent footgun: any short ISO/symbol code that
  happened to match a method already defined on `Object` (`try`, `then`,
  `tap`, `send`, `display`, `format`, ...) would raise
  `Amount::Registry::AlreadyRegistered` at boot. The first reported
  manifestation was `:TRY` (Turkish Lira) under Rails, where ActiveSupport's
  `Object#try` made the gem unusable for any application that needed to
  denominate amounts in Turkish Lira.
- The collision check in `GeneratedConstructors#raise_collision!` is kept as
  a defensive backstop, but with the `of_` prefix it should never fire in
  practice.

### Migration

Search-and-replace `Amount.<symbol>(` with `Amount.of_<symbol>(` across your
codebase. Any place that builds an `Amount` from a registered symbol uses one
of the generated constructors; everywhere else (`Amount.new`,
`Amount.parse`, `Amount.register`, `Amount.registry`, `Amount.with_registry`)
is unchanged.

## 0.0.7 - 2026-05-03

### Fixed

- `Display#to_s` now formats the decimal value using `ui_decimals`, matching
  `ui(decorated: false)`. Previously `to_s` used raw `BigDecimal#to_s("F")`
  which dropped trailing zeros (`USDC|1.5` instead of `USDC|1.50`), defeating
  the purpose of the compact format carrying the display-ready amount.
- `Amount#as_json` returns the compact string (`to_s`), preventing a
  `SystemStackError` (stack level too deep) when calling `as_json` or `to_json`
  on an Amount in Rails. The circular reference between `Display` and `Amount`
  caused ActiveSupport's default recursive serialization to overflow.

## 0.0.6 - 2026-04-28

### Added

- `trim_zeros` option for `Amount.register` strips trailing zeros from `ui`
  output. Defaults to `false` so fiat currencies keep fixed decimals (`$1.50`).
  Set `true` for tokens with high precision to get clean output (`1.5 SOL`
  instead of `1.5000 SOL`). Display units can override via
  `display_units: { gram: { ..., trim_zeros: false } }`.
- `Amount#ui(trim_zeros:)` call-site override. Pass `true` or `false` to
  override the registry and display-unit settings for a single render.
  Precedence: call-site > display unit spec > registry default.
- Railtie `initializer` block that auto-requires `amount/active_record` in
  Rails apps. `has_amount` and `t.amount` are now available without manual
  `require` statements — Bundler's auto-require of the `amounts` gem handles
  everything.

## 0.0.5 - 2026-04-26

### Added

- `Amount#ui(decorated: false)` returns the rounded UI value as a plain
  numeric string without the `display_symbol` prefix or suffix. Useful when
  the caller renders the currency label separately (e.g. in a column header
  or chip). Composes with `unit:` and `direction:` — for example,
  `Amount.of_gold("1").ui(unit: :gram, decorated: false)` returns `"31.10"`.
  Default remains `decorated: true`, so existing callers see no change.

## 0.0.4 - 2026-04-26

### Changed (breaking)

- The opt-in RSpec integration moved into a dedicated `Amount::RSpec` namespace
  with one file per concern. Constants and require paths changed:

  | Old | New |
  | --- | --- |
  | `Amount::RSpecMatchers` | `Amount::RSpec::Matchers` |
  | `Amount::RSpecSupport`  | `Amount::RSpec::Support`  |
  | `lib/amount/rspec_matchers.rb` | `lib/amount/rspec/matchers.rb` |
  | `lib/amount/rspec_support.rb`  | `lib/amount/rspec/support.rb`  |

  The ActiveRecord-specific matchers also live in their own file under the same
  pattern (`Amount::ActiveRecord::RSpec::Matchers` in
  `lib/amount/active_record/rspec/matchers.rb`). Top-level `require` paths
  (`require "amount/rspec"` and `require "amount/active_record/rspec"`) are
  unchanged.

  Update any direct constant references; no backwards-compatibility aliases are
  shipped.

### Changed

- The `Amount` instance behavior is now composed from focused mixins instead
  of all living in a single 500+ line file. New modules under `lib/amount/`:
  `Arithmetic` (`+`, `-`, `*`, `/`, `abs`, `-@`),
  `Comparison` (`<=>`, `==`, `eql?`, `hash`, `same_type?`, sign predicates),
  `Conversion` (`to(target_symbol, rate:)`),
  `Allocation` (`split`, `allocate`),
  and `Serialization` (instance `to_h` plus `Serialization::ClassMethods.load`
  auto-extended via the `included` hook).
  Public API unchanged. Shared private helpers (`build`,
  `coerce_other_to_self_type[!]`, `ensure_same_type!`, `infer_value`,
  `infer_type`, `ui_to_atomic`) remain on the main `Amount` class so every
  mixin can call them.

### Removed

- `Amount::Serializer` is gone. Its `dump`/`load` class methods moved into
  `Amount::Serialization` (instance `to_h` plus `ClassMethods.load`).
  `Amount.load(hash)` and `Amount#to_h` are unchanged.

## 0.0.3 - 2026-04-26

### Fixed

- Rational scalars and rates are now accepted everywhere they are documented to
  work: `Amount#*`, `Amount#/`, `Amount#to(rate:)`, `Amount.register_default_rate`,
  and `display_units[unit][:scale]`. Previously each of these called
  `BigDecimal(value.to_s)`, which raises `ArgumentError` for `Rational#to_s`
  (`"3/2"`). All five sites now go through a single internal helper,
  `Amount.coerce_decimal`, that handles `BigDecimal`, `Rational`, and string-or-
  numeric inputs uniformly.
- `Amount.load` wraps a missing `:atomic` or `:symbol` key as
  `Amount::InvalidInput` (`"amount payload missing key: atomic"`) instead of
  leaking a raw `KeyError`. This matches the AR adapter's `Type#cast_hash`
  behavior so callers can rescue a single error class.

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
