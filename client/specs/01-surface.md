# 01 — Surface

**The client mirrors the gem's core, and nothing else.** A Rails app exports
its registry as a manifest; the client reads that manifest and does
everything the core `Amount` class does — on the same atomic integers, with
the same rounding, producing the same strings. A value parsed, computed and
displayed in the browser is byte-for-byte the value the server would have
produced.

## Why a manifest, not a second registry

The registry is configuration that already lives in one place — the Rails
initializer. Re-declaring it in JavaScript would be a second source of truth
that drifts. So the gem exports it (`Amount.manifest`, see
[02](./02-manifest.md)), and the client is constructed from that export.
The client never registers a type of its own.

## In scope — the gem's core, mirrored

| Gem (core)                                   | Client                                          |
| -------------------------------------------- | ----------------------------------------------- |
| `Amount.registry` (types, default rates)     | `Amounts.fromManifest(manifest)`                |
| `Amount.new(value, :SYM, from:)`, `of_sym`   | `amounts.of("SYM", value, { from })`            |
| `Amount.parse("USDC\|1.50")` (+ `v1:` form)  | `amounts.parse(...)`                            |
| `Amount.parse_ui(input, :SYM, locale:)`      | `amounts.parseUi(input, "SYM", { locale })`     |
| `Amount.load(v:, atomic:, symbol:)`          | `amounts.load(payload)`                         |
| `+ - * /`, `abs`, `-@`                       | `add subtract multiply divide abs negate`       |
| `Amount / Amount` (ratio)                    | `divide(other)` → `Ratio`                       |
| `<=> == < > ...`, `zero? positive? negative?`| `compare equals lessThan ... isZero ...`        |
| `same_type?`                                 | `sameType(other)`                               |
| `to(:SYM, rate:)`                            | `to("SYM", { rate })`                           |
| `split(n)`, `allocate(weights)`              | `split(n)`, `allocate(weights)`                 |
| `atomic`, `symbol`, `decimals`, `decimal`    | same names; `atomic` is a `bigint`, `decimal` an exact string |
| `to_h`, `as_json`, `to_s`, `formatted`       | `toHash()`, `toJSON()`, `toString()`, `formatted()` |
| `ui(unit:, direction:, decorated:, trim_zeros:, locale:, compact:)` | `ui({ unit, direction, decorated, trimZeros, locale, compact })` |
| `unit_label`, `display_format`, `in_unit`    | `unitLabel`, `displayFormat`, `inUnit`          |
| `Amount.localize = true` + `I18n.locale`     | `Amounts.fromManifest(manifest, { locale })`    |
| Locale-aware output and input (I18n)         | the manifest's exported locale tables           |

## Out of scope

- **The ActiveRecord adapter** (`has_amount`, aggregates, bulk writes) — it
  is persistence, and persistence is the server's.
- **Registering types or rates in the client.** The manifest is the only
  way in, and a client's registry is frozen from birth (the gem's `lock!`).
- **Custom subclasses** (`class: GoldAmount`). A Ruby class can't cross the
  wire; the client has one `Amount` class.
- **RSpec matchers and the Rails generator.**
- **I18n itself.** The client never reads translation files; the gem
  resolves every lookup the core performs and writes the results into the
  manifest (see [02](./02-manifest.md#locales)).

## Decisions that differ from Ruby, and why

JavaScript lacks some of what the gem leans on. Each gap is closed the way
that keeps values exact; none of them changes a result.

1. **Atomic values are `bigint`.** `Number` loses integers past 2^53; an
   atomic count of wei passes that before one ETH.
2. **Integer vs Float inference.** Ruby reads an `Integer` as atomic and a
   `Float` as a UI value. JavaScript's `1` and `1.0` are the same `number`,
   so the client splits on type instead: **`bigint` is atomic, `string` and
   `number` are UI values** (a `number` goes through its string form, like
   a Ruby `Float`). `{ from: "atomic" }` reads a `number` or digit `string`
   as atomic, the way `from: :atomic` does.
3. **Exact decimals are strings.** Where Ruby returns a `BigDecimal`
   (`decimal`, `in_unit`), the client returns its exact plain-decimal
   string (`"1.5"`, as `to_s("F")` writes it). A scalar or rate may be
   given as a decimal string — the client's stand-in for `BigDecimal`.
4. **`Amount / Amount` returns a `Ratio`**, an exact fraction of two
   `bigint`s. Ruby's `BigDecimal` quotient is rounded to an internal
   precision; a fraction never is.
5. **Operators are methods.** `a.add(b)`, `a.lessThan(b)`.
6. **Instances are frozen.** As in Ruby, every operation returns a new
   amount.
7. **Errors are one class with a code** (`AmountError`, `code:
   "TYPE_MISMATCH"`), in place of Ruby's exception hierarchy — matching
   how the codes are branched on in JavaScript. Every Ruby exception the
   core raises has a code.
8. **Display numbers are formatted exactly.** The gem's `ui` formats
   through `format("%.Nf")`, which goes through a `Float` and prints wrong
   digits past ~15 significant figures. The client formats the exact
   value, so the two agree everywhere the gem is right.
9. **Plural forms follow I18n's default rule** (`zero` when the count is 0
   and the form exists, `one` when it is 1, else `other`) — the rule the
   gem gets when no `rails-i18n` pluralization is installed.

## Runtime

- **Zero runtime dependencies.** `bigint` and string handling only — no
  `Intl`, no `Number` arithmetic on values, nothing a React Native engine
  (Hermes, RN ≥ 0.70) lacks.
- **ESM and CommonJS builds, with TypeScript declarations**, so it installs
  the same into Vite, webpack, Node and Metro.
- Written in TypeScript; plain JavaScript callers get the same API.
