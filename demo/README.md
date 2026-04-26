# amounts demo — Rails case-study harness

> **You are reading the demo package readme.** This Rails app lives inside
> the `zarpay/amounts` repository as a sibling of [`gem/`](../gem) and
> [`site/`](../site). See the [root README](../README.md) for the layout
> overview.

A Rails 8.1 application whose only purpose is to exercise every public
feature of the [`amounts`](../gem) gem in realistic ActiveRecord and
RSpec usage. Every file is annotated as a textbook so a reader can use
the demo to learn the gem in context.

## Why this exists

The demo serves three audiences simultaneously:

1. **Library users** — the four cookbook scenarios (Treasury, Vault,
   Yard, Exchange) show idiomatic patterns for each gem feature, with
   inline commentary explaining the *why* behind each choice.
2. **Library contributors** — `bundle exec rspec` here runs an
   integration suite of 334 examples against `../gem`. If a change to
   the gem regresses any documented behavior, this suite breaks.
3. **The gem author** — the harness was built alongside the gem and
   surfaced (or corroborated) every bug fixed in 0.0.2 through 0.0.5.
   See `spec/torture_spec.rb` for the working journal.

## Run it

```bash
bundle install
bin/rails db:migrate RAILS_ENV=test
bundle exec rspec
```

Current state: **334 examples, 0 failures**, 91% line coverage.

The Gemfile path-pins `gem "amounts", path: "../gem"`, so the demo
always tests against the in-tree gem source. Bumping the gem in `../gem`
takes effect immediately in `bundle exec rspec` here.

## How to read this app

Each file under `app/` and `spec/` opens with a header comment summarizing
the lesson it teaches. Read the files in this order — each builds on the
previous:

| Step | File | What it teaches |
|---|---|---|
| 1 | `config/initializers/amounts.rb` | Registry as the configuration surface: every option of `Amount.register` and `register_default_rate` |
| 2 | `app/models/gold_amount.rb` | Custom `Amount` subclass via the `class:` registry option |
| 3 | `db/migrate/*.rb` | Every variant of the `t.amount` migration DSL: multi-symbol, fixed-symbol, `precision:`, `default:`, `comment:`, check constraints |
| 4 | `app/models/treasury/{holding,transfer}.rb` | `has_amount` macro, both fixed and multi-symbol; full `validates :x, amount: { ... }` option matrix; generated query scopes; dirty tracking; cross-type arithmetic |
| 5 | `app/models/vault/gold_bar.rb` | `display_units`, `ui(unit:, direction:)`, `in_unit`, custom-class round-trip, `split` / `allocate` |
| 6 | `app/models/yard/log_shipment.rb` | `decimals: 0` integer-style amounts; `split` / `allocate` invariants |
| 7 | `app/models/exchange/trade.rb` | Asymmetric directional rates, cross-type `+ - <=>`, explicit `.to(:SYMBOL, rate:)` |
| 8 | `spec/factories/*.rb` | Every input form the AR writer accepts: `Amount` instance, compact string, `{atomic:, symbol:}` hash, `{value:, symbol:}` hash, raw numeric for fixed-symbol |
| 9 | `spec/registry_spec.rb` | Registration, locking, `with_registry`, generated constructors, error classes, thread safety |
| 10 | `spec/amount_spec.rb` | Pure value-object behavior: construction, arithmetic, comparison, conversion, split/allocate, formatting, serialization |
| 11 | `spec/type_spec.rb` | The public `Amount::ActiveRecord::Type` API exercised directly |
| 12 | `spec/validators/amount_validator_spec.rb` | Every option of the `validates :x, amount: { ... }` validator |
| 13 | `spec/models/**/*_spec.rb` | Per-model coverage: schema, casting matrix, dirty tracking, scopes, validations, callbacks |
| 14 | `spec/integration/*.rb` | One end-to-end scenario per cookbook plus a full-surface custom-class spec |
| 15 | `spec/matchers/*.rb` | Every gem-provided RSpec matcher demonstrated |
| 16 | `spec/torture_spec.rb` | Adversarial inputs: numeric extremes, symbol weirdness, format-injection, concurrency, frozen instances |

## The four cookbook domains

Each domain in `app/models/` mirrors a published cookbook example so
the demo can lift assertions verbatim from the gem's docs.

| Domain | Models | Symbols | Lessons |
|---|---|---|---|
| Treasury | `Treasury::Holding`, `Treasury::Transfer` | USDC, USD, SOL | Multi-symbol amounts; fixed-symbol fees; default sentinels; full validator matrix; generated `where_*` scopes |
| Vault | `Vault::GoldBar` | GOLD | Display units, custom subclass through AR adapter, splitting bullion |
| Yard | `Yard::LogShipment` | LOGS | `decimals: 0`, exact split/allocate semantics, negative-amount invariants |
| Exchange | `Exchange::Trade` | EMBER, SILVER, USD | Asymmetric directional rates, cross-type arithmetic, explicit conversions |

## RSpec features in use

`let` / `let!` / `subject`, `before` / `after` / `around`, `shared_examples`,
`shared_context`, `it_behaves_like`, `include_examples`,
`define_negated_matcher`, `expect { … }.to change(…)`, `aggregate_failures`
on by default via derived metadata, `filter_run_when_matching :focus`,
`example_status_persistence_file_path`, factory_bot, faker,
shoulda-matchers, simplecov.

## ActiveRecord features in use

Migrations (`t.amount` with every option), `add_check_constraint`,
foreign keys, indexes, validations (built-in + custom `AmountValidator`),
generated query scopes, custom scopes layered on top, `belongs_to` /
`has_many`, `before_validation` / `after_save` callbacks, dirty tracking,
`group(...).sum(...)` aggregations, transactional spec isolation.

## Gem releases this demo drove

The harness surfaced bugs and design issues during construction. Each
release below resolves at least one finding made here.

| Version | What shipped |
|---|---|
| 0.0.2 | Custom-class amounts now round-trip through ActiveRecord; Rational UI input accepted; numeric thresholds accepted on multi-symbol AmountValidator |
| 0.0.3 | Rational coercion centralized at five additional sites (`*`, `/`, `to(rate:)`, `register_default_rate`, `display_units[unit][:scale]`); `Amount.load` wraps missing-key errors as `InvalidInput` |
| 0.0.4 | Blank-symbol guard at registration; frozen `Amount` can render display; RSpec integration moved into `Amount::RSpec::*` namespace; `Amount` instance behavior split into focused mixins (`Arithmetic`, `Comparison`, `Conversion`, `Allocation`, `Serialization`); `Amount::Serializer` collapsed into `Amount::Serialization` |
| 0.0.5 | `Amount#ui(decorated: false)` returns the rounded UI value without the display symbol |

`spec/torture_spec.rb` is the working journal for that process — it
documents the inputs the harness threw at the gem and which ones exposed
real bugs.
