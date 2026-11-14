# Changelog

## 0.3.1 - 2026-11-15

### Added

- `sum_amount`, `minimum_amount`, `maximum_amount` and `average_amount` take
  several `has_amount` attributes and aggregate them all in one query, returning
  a Hash by attribute name (per group when grouped) in place of each Amount, as
  Rails' `pluck` returns rows for several columns. A model with several amounts
  on one table no longer pays one round trip per amount over the same rows.
  Each attribute folds exactly as it would alone, with the same symbol rule. With
  several attributes, a group appears when it has any row, and an attribute with
  no amount in it gets the empty-set result (zero for a fixed-symbol sum, else
  `nil`). A name given twice raises `ArgumentError`. With one attribute, nothing
  changes.

## 0.3.0 - 2026-11-15

### Added

- `Amount.manifest(locales: [])` exports the registry as a JSON-ready Hash for
  a client in another language to mirror: every type (with the
  `Amount.register` option names), every default rate as an exact decimal
  string, and for each requested locale every translation the core looks up,
  already resolved. The new `@zarpay/amounts` JavaScript client is built from
  it. Locales need I18n.
- `Amount::Registry#default_rates` returns every registered default rate,
  keyed by `[from, to]`.
- `Amount::Compact.locale_format(locale)` is public.

### Fixed

- **Breaking:** `ui` and `to_s` round negative amounts by magnitude, like
  their positive. `direction: :floor` (the default) now rounds toward zero and
  `:ceil` away from it; before, `:floor` rounded toward negative infinity, so
  a negative displayed more than it was (`-1.234` showed as `$-1.24`, and
  `-0.001` as `$-0.01`). It now shows `$-1.23` and `$0.00`, and a value that
  rounds to zero has no sign. Compact notation follows (`-1_999_999` is
  `-1.99M`, was `-2M`). Positive amounts are unchanged. This matches `*`, `/`,
  `to`, `split` and `allocate`, which already truncate toward zero. Migration:
  code or tests that expect the old output for an inexact negative amount
  should expect its positive's digits; pass `direction: :ceil` for the
  larger magnitude.

## 0.2.0 - 2026-11-14

### Added

- `amount_changes` and `saved_amount_changes` on models with `has_amount`:
  Rails' `changes` and `saved_changes` with each amount by name, as
  `[before, after]` Amounts, in place of its component columns. Rails' own
  change hashes are unchanged.
- `Model.amount_column_values(attributes)` turns attributes, with amounts by
  name, into column values for `insert_all`, `upsert_all` and their variants,
  which skip attribute writers. Each amount is cast as its writer would cast
  it and replaced by its component columns (all of them even for `nil`, so
  rows share keys); other keys pass through. A fixed-symbol amount in another
  symbol raises `Amount::TypeMismatch`, since bulk writes skip validations.
- SQL aggregates for `has_amount` attributes that return Amounts:
  `sum_amount`, `minimum_amount`, `maximum_amount` and `average_amount`. Each
  runs one query in the scope of the relation it's called on, so `where`,
  `group` and associations apply. Grouped, the result is keyed like Rails'
  `group(...).sum`. A multi-symbol attribute with more than one symbol in
  scope, or in one group, raises `Amount::TypeMismatch`; group by its symbol
  column for one Amount per symbol. A fixed-symbol sum over no rows is zero;
  other empty results are `nil`. `average_amount` truncates toward zero to a
  whole atomic unit, as `Amount#/` does. Grouping by an association name
  raises `ArgumentError` (group by its foreign key). On SQLite, aggregates
  past 64 bits raise `integer overflow` or come back inexact; PostgreSQL is
  exact.

### Changed

- **Breaking:** a model with `has_amount` serializes each amount by its name,
  as its exact compact string, in place of its component columns:
  `as_json` gives `"owed" => "USD|10.06"`, not `"owed_atomic" => "1006.0"`
  (`serializable_hash` holds the Amount). `only:` and `except:` take the
  amount's name. `has_amount` includes this into the declaring model;
  `ActiveRecord::Base` and models without amounts are unchanged.

  Migration: JSON readers that read `<name>_atomic` / `<name>_symbol` read
  `<name>` instead and parse it with `Amount.parse`. Code that needs the raw
  columns reads them from `attributes`
  (`record.attributes.slice("owed_atomic")`).
- **Breaking:** `Amount#as_json` (and so `to_json`) writes the exact compact
  string: whole units with exactly the symbol's `decimals` places
  (`"USDC|1.500000"`, `"SOL|1.123456789"`). It previously returned `to_s`,
  which rounds down to `ui_decimals`, so JSON silently dropped digits past it
  (`"SOL|1.1234"` for 1.123456789 SOL).

  Migration: clients that read the value with `Amount.parse` or as a number
  need no change. Where JSON output was compared as a string (tests,
  fixtures) or shown to people, expect the longer form, or use `to_s` or `ui`
  for display.

### Fixed

- `Amount#/` by a scalar computes the quotient exactly (in `Rational`) before
  truncating it toward zero. It divided in `BigDecimal`, which rounds the
  quotient to a limited precision, so large amounts divided by small decimals
  came out wrong: 10^40 atomic units divided by `BigDecimal("7e-21")` was off
  by 1429 atomic units. Results that were already exact are unchanged.
  `average_amount` divides this way.
- A subclass of a model with `has_amount` (STI included) inherits its
  parent's amount definitions. It previously started with none, so
  `amount_attribute_definitions`, `amount_atomic_column` and friends raised
  `KeyError` on the subclass, and so did the `amount:` validator and the
  `have_amount_column` matcher for inherited amounts. Amounts a subclass
  declares stay off its parent and siblings. `amount_attribute_definitions`
  is now a `class_attribute` holding a frozen Hash.

## 0.1.0 - 2026-11-02

### Added

- Compact notation for large numbers: `ui(compact: true)` renders `50M TOKENS`
  or `$1.5M`. It keeps 3 significant digits (`compact: { precision: 2 }` to
  change it), rounds in `direction:` (so `1_999_999` floors to `1.99M`), trims
  trailing zeros and moves up a scale when rounding reaches it. Numbers below
  one thousand are formatted as usual. Scale words run from `K`/`M`/`B`/`T`
  through `Qa`/`Qi`/`Sx`/`Sp`/`Oc`/`No` to `Dc` (decillion, 10^33), joined
  as `"%n%u"`; when localizing they come from
  `number.human.decimal_units.units` (pluralized with the compacted number)
  joined by `number.human.decimal_units.format` (default `"%n %u"`), falling
  back to the short form for a missing word. Works with `unit:` (the scaled
  number is compacted), labels and templates (which wrap the compacted
  number; plural labels agree with the full value) and `decorated: false`.
  Output without `compact:` is unchanged.
- `Amount.parse_ui(input, symbol, locale: nil)` parses what a person types in a
  locale's number format: `parse_ui("1.500,50", :USD, locale: :de)` and
  `parse_ui("1,500.50", :USD, locale: :en)` both give `USD|1500.50`. The
  effective locale is `locale:`, then `I18n.locale` when `Amount.localize` is
  true, else plain parsing (`.` decimal, no delimiters). Accepts surrounding
  whitespace (including NBSP), a leading `-` or `+`, delimiters in correct
  groups of three, and the type's label or display symbol at either end in any
  plural form (`"$1,500.50"`, `"1.500,50 €"`). Raises `InvalidInput` for more
  decimals than the type has (never rounds), misplaced delimiters, a repeated
  separator, another type's label, or empty input. Returns the type's
  registered class; an unregistered symbol raises as `Amount.new` does.
  `Amount.parse` and the constructors are unchanged. Wiring it into the
  ActiveRecord type is not part of this change.
- Templates for where the number and unit go. `register` takes
  `display_format:` and display unit specs take `format:`, where `%n` is the
  formatted number (sign included) and `%u` the label: `"%u%n"`,
  `"%n\u00A0%u"`. Templates are used exactly as given, so non-breaking spaces
  survive. When localizing, `amounts.formats.<symbol downcased>` and
  `amounts.display_unit_formats.<symbol downcased>.<unit>` override them; a
  locale template without `%n` is ignored. `display_position` stays as
  shorthand for `"%u%n"` / `"%n %u"`, so existing output is unchanged.
  Passing both `display_format:` and `display_position:` raises
  `ArgumentError`; a display unit with both `:format` and `:position` raises
  `InvalidDisplayUnit`. `Registry::Entry#display_format` always holds the
  type's template, and `#display_position` is `nil` for a type registered
  with `display_format:`.
- `Amount#display_format(unit: nil, locale: nil)` returns the template `ui`
  uses for the type or a display unit, with the same locale precedence.
  Template behavior lives in the new `Amount::Formattable` concern, included
  in `Amount`.
- `Registry::Entry#display_unit(unit)` returns a display unit's spec, raising
  `InvalidDisplayUnit` for an unknown unit.
- Plural unit labels. `display_symbol:` (and a display unit's `symbol:`) accept
  a hash such as `{ one: "search", other: "searches" }`, giving `1 search` /
  `2 searches`. `register` raises (`Registry::InvalidDisplaySymbol`, or
  `InvalidDisplayUnit` for a unit) unless the hash has `:other` and maps
  Symbols to Strings. The count is the displayed number (after scaling and
  rounding). Without localizing, `:one` is used when it equals 1, else
  `:other`; when localizing, I18n translations and hashes are pluralized with
  `count:` through the locale's rules (`few`, `many`, ...). A missing form falls
  back to `:other`. `unit_label` takes `count:`; without it the `:other` form is
  used. String labels are unchanged.
- Unit labels can come from I18n. `register` takes `label_key:` (String or
  Symbol); without it the key is `amounts.units.<symbol downcased>`. Display
  units take `label_key:` in their spec, defaulting to
  `amounts.display_units.<symbol downcased>.<unit>`. Lookups only happen when
  localizing (`locale:` or `Amount.localize = true`). Fallbacks: a type falls
  back to `display_symbol`; a display unit to its `:symbol`, then the type's
  label. A missing key never renders "translation missing". Output is
  unchanged when not localizing.
- `Amount#unit_label(unit: nil, locale: nil)` returns the label alone, with
  the same rules as `ui`, for column headers and chips.
- `ui` can format numbers for a locale: `ui(locale: :de)` uses the locale's
  `number.format` delimiter and separator (`"$122.500,00"`), falling back to
  `,` and `.` for missing keys. Works with `unit:`, `decorated: false`,
  `trim_zeros` and `direction`.
- `Amount.localize = true` makes `ui` use `I18n.locale` when no `locale:` is
  given. It defaults to `false`, so output is unchanged unless you opt in.
  Passing `locale:` or setting `Amount.localize = true` without the `i18n` gem
  loaded raises `ArgumentError`. `to_s`, `formatted`, `as_json`, serialization
  and `Amount.parse` never change with the locale.

### Changed

- `Amount`'s internal concern modules are renamed as -able adjectives and live
  in `lib/amount/concerns/`: `Arithmetic` → `Calculable`, `Allocation` →
  `Allocatable`, `Comparison` → `Orderable`, `Conversion` → `Convertible`,
  `Serialization` → `Serializable` (`Formattable` is unchanged). Five new
  concerns hold logic that used to sit in `Amount` itself: `Registrable`,
  `Localizable`, `Parsable`, `Constructible` and `Coercible`. None of these
  modules are documented API, and every `Amount` method is unchanged. Code
  that referenced a module by name, or required a file under `amount/`
  other than the documented entry points, should `require "amount"` and call
  `Amount`'s methods.
- `AmountValidator` now adds errors by I18n key instead of hard-coded English
  strings, so apps can translate or reword them: `:amount_type`,
  `:amount_symbol`, `:amount_invalid_constraint`, `:amount_incomparable`, plus
  Rails' own `:greater_than`, `:greater_than_or_equal_to`, `:less_than`,
  `:less_than_or_equal_to` and `:invalid`. English defaults ship in
  `lib/amount/active_record/locale/en.yml`, loaded into `I18n.load_path` when
  `amount/active_record` is required (once, with or without Rails). With no app
  translations, message text is unchanged. `errors.details` now reports the
  keys and interpolation values.

### Fixed

- Anonymous ActiveRecord classes using `has_amount` get a fallback
  `model_name`, so validation messages can be generated for them.
- On Rails 8.1, assigning an amount whose atomic value has more than 16 digits
  (`Amount.new(10**30, :SOL, from: :atomic)`) silently truncated it before
  saving (to `10**15`). Rails 8.1 cuts a string cast to an integer column to
  16 bytes, and `has_amount` wrote the atomic value as a string. It now writes
  the Integer, which every Rails version stores exactly. Reads were never
  affected; rows already written under Rails 8.1 with more than 16 digits
  hold the truncated value.

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
