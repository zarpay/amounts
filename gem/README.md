> **You are reading the gem package readme.** The repository also contains
> [`site/`](../site) (the docs site) and [`demo/`](../demo) (a Rails
> case-study app that exercises every feature). See the
> [root README](../README.md) for the layout overview.

# amounts

[![Gem Version](https://img.shields.io/gem/v/amounts)](https://rubygems.org/gems/amounts)
[![CI](https://github.com/zarpay/amounts/actions/workflows/ci.yml/badge.svg)](https://github.com/zarpay/amounts/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/zarpay/amounts)](https://github.com/zarpay/amounts/releases)
[![License](https://img.shields.io/github/license/zarpay/amounts)](https://github.com/zarpay/amounts/blob/main/gem/LICENSE.txt)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.1-red)](https://rubygems.org/gems/amounts)

`amounts` is a Ruby gem for precise quantities of fungible things: money, crypto tokens, commodities, inventory units, points, and similar value-like amounts. It stores every value as an arbitrary-precision atomic `Integer`, keeps type identity in a registry, rejects accidental cross-type math unless an explicit directional rate exists, and offers an optional ActiveRecord adapter without making Rails part of the core runtime.

## Installation

```bash
bundle add amounts
```

or:

```bash
gem install amounts
```

The library entrypoint is:

```ruby
require "amount"
```

Load the Rails adapter only when needed:

```ruby
require "amount/active_record"
```

If the gem is bundled into a Rails app, the Rails-only generator hooks are
loaded through the adapter railtie. You do not need a separate top-level
generator require.

## Quickstart

```ruby
require "amount"

Amount.register :USDC,
  decimals: 6,
  display_symbol: "$",
  display_position: :prefix,
  ui_decimals: 2

Amount.register :USD,
  decimals: 2,
  display_symbol: "$",
  display_position: :prefix,
  ui_decimals: 2

Amount.register_default_rate :USD, :USDC, 1

usdc = Amount.usdc("10.00")
usd = Amount.new("5.00", :USD)

(usdc + usd).ui
# => "$15.00"
```

## Concepts

### Atomic vs. UI values

`Amount` stores values as atomic integers in the smallest registered unit for that type.

```ruby
Amount.register :USDC, decimals: 6

amount = Amount.new("1.5", :USDC)
amount.atomic
# => 1500000

amount.decimal.to_s("F")
# => "1.5"
```

Construction rules:

- `Integer` defaults to atomic units
- `String` defaults to UI decimal values
- `Float`, `BigDecimal`, and `Rational` are treated as decimal UI values
- `from: :atomic`, `:ui`, or `:float` overrides inference
- registering `:USDC` also defines `Amount.usdc(...)` when the symbol is a valid Ruby method name

### Registry

The registry defines the full behavior of each type:

```ruby
Amount.register :GOLD,
  decimals: 8,
  display_symbol: "oz t",
  display_position: :suffix,
  ui_decimals: 4,
  display_units: {
    oz_t: { scale: 1, symbol: "oz t", ui_decimals: 4 },
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2 }
  },
  default_display: :oz_t
```

Boot-time registry configuration can be frozen once setup is complete:

```ruby
Amount.registry.lock!
Amount.registry.locked? # => true
```

### Display units are not conversions

Display units scale presentation only:

```ruby
gold = Amount.new("1.5", :GOLD)
gold.ui(unit: :gram)
# => "46.65 g"
```

The value is still `:GOLD`.

### Directional conversion rates

Cross-type `+`, `-`, and `<=>` only work when the right-hand side can be converted into the left-hand side using a registered default rate.

```ruby
Amount.register_default_rate :USD, :USDC, 1

Amount.new("10", :USDC) + Amount.new("5", :USD)
# => #<Amount USDC|15.0>
```

Rates are directional. `:USD -> :USDC` does not imply `:USDC -> :USD`.

### Split vs. division

Scalar division returns one scaled amount:

```ruby
Amount.new("10", :USDC) / 2
# => #<Amount USDC|5.0>
```

`split` and `allocate` return explicit remainders:

```ruby
parts, remainder = Amount.new(10, :LOGS).split(3)
parts.map(&:atomic)  # => [3, 3, 3]
remainder.atomic     # => 1
```

Negative values follow the same rules with rounding toward zero:

```ruby
parts, remainder = Amount.new(-10, :LOGS).allocate([1, 1, 1])
parts.map(&:atomic)  # => [-3, -3, -3]
remainder.atomic     # => -1
```

## Core API

### Construction

```ruby
Amount.new(1_500_000, :USDC)
Amount.new("1.50", :USDC)
Amount.usdc("1.50")
Amount.parse("USDC|1.50")
Amount.load(atomic: 1_500_000, symbol: :USDC)
```

### Math

```ruby
a = Amount.new("10", :USDC)
b = Amount.new("2", :USDC)

a + b
a - b
a * 2
a / 2
a / b
```

`Amount * Amount` raises `Amount::TypeMismatch`.

### Comparison

```ruby
Amount.new("1", :USDC) < Amount.new("2", :USDC)
```

Cross-type comparison returns `nil` when no directional rate exists.

### Conversion

```ruby
Amount.new("10", :USDC).to(:USD, rate: "1")
```

### Display

```ruby
amount.formatted
amount.ui
amount.ui(direction: :ceil)
amount.ui(unit: :gram)
amount.in_unit(:gram)
```

### Serialization

```ruby
payload = amount.to_h
Amount.load(payload)
```

## Registry API

```ruby
Amount.register(...)
Amount.register_default_rate(:USD, :USDC, "1")
Amount.registry.lookup(:USDC)
Amount.registry.symbols
Amount.registry.clear!
Amount.registry.lock!
Amount.registry.locked?
```

## ActiveRecord Integration

Load the adapter explicitly:

```ruby
require "amount/active_record"
```

### Preset registry generator

In a Rails app, you can generate a starter initializer with curated baskets of
registered symbols:

```bash
bin/rails generate amounts:registry fiat
bin/rails generate amounts:registry metals
bin/rails generate amounts:registry crypto
bin/rails generate amounts:registry all
```

The generator writes `config/initializers/amounts.rb` with registration
metadata only. It intentionally does not register default conversion rates,
because those are directional and application-specific.

### Migration DSL

```ruby
create_table :holdings do |t|
  t.amount :amount
  t.amount :default_amount, default: "USDC|1.25"
  t.amount :fee, symbol: :SOL
  t.amount :reserve, precision: 40
end
```

This generates:

- `*_atomic` as `numeric(78, 0)` by default
- `*_symbol` as `string(10)` for multi-symbol amounts
- `precision:` override support for the atomic column

### Model Macro

```ruby
class Holding < ApplicationRecord
  has_amount :amount
  has_amount :fee, symbol: :SOL
end

holding = Holding.new
holding.amount = "USDC|1.50"
holding.fee = 0.25
```

Writers accept:

- `Amount`
- `String` like `"USDC|1.50"`
- `Hash` payloads
- raw numeric values for fixed-symbol attributes only

Scopes:

```ruby
Holding.where_amount("USDC|1.50")
Holding.where_amount_gt("USDC|1.00")
Holding.where_amount_gte("USDC|1.00")
Holding.where_amount_lt("USDC|5.00")
Holding.where_amount_lte("USDC|5.00")
Holding.where_amount_between("USDC|1.00", "USDC|5.00")
Holding.amount_in(:USDC)
```

Suggested check constraint for multi-symbol amounts:

```sql
ALTER TABLE holdings ADD CONSTRAINT amount_both_or_neither
  CHECK ((amount_atomic IS NULL) = (amount_symbol IS NULL));
```

### SQLite Note

The adapter supports SQLite for general integration tests and development, but SQLite does not preserve `DECIMAL(78,0)` values above 64-bit range exactly under ActiveRecord's default numeric handling. For exact wei-scale persistence, use PostgreSQL or another database with true arbitrary-precision numeric behavior.

### PostgreSQL Dummy App

A minimal Rails dummy app lives under `test/dummy` for PostgreSQL-backed integration testing.

Run the default suite:

```bash
bundle exec rake
```

Run the PostgreSQL integration test explicitly:

```bash
AMOUNTS_POSTGRES_URL=postgresql://localhost/amounts_test \
  bundle exec ruby -Ilib:test test/postgresql_integration_test.rb
```

If `AMOUNTS_POSTGRES_URL` is not set, the PostgreSQL test file skips cleanly.

Open a console against the dummy app:

```bash
AMOUNTS_POSTGRES_URL=postgresql://localhost/amounts_test \
  test/dummy/bin/rails console
```

## Testing

The gem ships opt-in RSpec matchers for app-level specs:

```ruby
# spec/spec_helper.rb
require "amount/rspec"
require "amount/active_record/rspec"
```

Core matcher examples:

```ruby
expect(holding.amount).to eq_amount("USDC|1.50")
expect(holding.amount).to be_amount_of(:USDC)
expect(holding.amount).to be_positive_amount
expect(converted).to be_approximately_amount(:GOLD, "0.0042", within: "0.0001")
```

ActiveRecord matcher examples:

```ruby
expect(holding).to have_amount_column(:amount, "USDC|1.50")
expect(Holding.group(:amount_symbol).sum(:amount_atomic))
  .to match_amounts(USDC: "10500.00", SOL: "12.5")
```

The gem's own test suite runs both Minitest and RSpec:

```bash
bundle exec rake
bundle exec rspec
```

## Releases

RubyGems publishing is intended to run from GitHub Releases using RubyGems trusted publishing.

Workflow:

- create and push a version tag such as `v0.0.1`
- publish a GitHub Release for that tag
- GitHub Actions runs `.github/workflows/release.yml`
- the workflow verifies the test suite and publishes the gem to RubyGems.org

RubyGems setup:

- on RubyGems.org, configure a trusted publisher for the `amounts` gem
- repository owner: `zarpay`
- repository name: `amounts`
- workflow filename: `release.yml`
- GitHub Actions environment: `release`

This uses OIDC trusted publishing, so no RubyGems API token needs to be stored in GitHub Actions. See the official RubyGems trusted publishing guide:

- https://guides.rubygems.org/trusted-publishing/

## Compared to `money`

`money` is excellent for fiat currency workflows and has a mature ecosystem. `amounts` takes a different tradeoff:

| Concern | `money` | `amounts` |
| --- | --- | --- |
| Internal storage | integer subunits | arbitrary-precision atomic integer |
| Non-fiat tokens | awkward at high decimals | first-class |
| Cross-type math | money-oriented exchange features | explicit directional rates only |
| Display units | currency formatting | arbitrary per-type display scaling |
| Rails dependency | common usage path | optional adapter only |

## Contributing

1. Install dependencies with `bin/setup`
2. Run `bundle exec rake`
3. Keep the core gem Rails-agnostic
4. Add tests for behavioral changes

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
