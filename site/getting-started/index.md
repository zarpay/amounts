# Quick Start

This page gets one small application model running end-to-end: an **Orbit Treasury** that tracks `USDC`, `USD`, and `SOL`.

## Install the gem

```ruby
gem "amounts"
```

```bash
bundle install
```

For Rails integration later:

```ruby
require "amount/active_record"
```

## Register the types you care about

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

Amount.register :SOL,
  decimals: 9,
  display_symbol: "SOL",
  display_position: :suffix,
  ui_decimals: 4

Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"
```

That does four things:

1. Defines the storage precision for each type
2. Defines how each type should display by default
3. Generates convenience constructors like `Amount.of_usdc(...)`
4. Registers directional conversion rules for cross-type arithmetic

## Construct values

```ruby
treasury_buffer = Amount.of_usdc("150000.00")
invoice = Amount.new("2500.00", :USD)
gas_budget = Amount.of_sol("18.75")
```

Construction defaults are intentional:

- `Integer` means atomic units
- `String` means UI value
- `Float`, `BigDecimal`, and `Rational` mean UI value
- `from:` overrides inference explicitly

## Do math safely

```ruby
(treasury_buffer - invoice).ui
# => "$147500.00"

treasury_buffer > invoice
# => true
```

That works because the right-hand side can be converted from `USD` into `USDC` using the registered directional rate.

Without a rate:

```ruby
Amount.of_usdc("10") + Amount.of_sol("1")
# => raises Amount::TypeMismatch
```

## Serialize and parse

For client-facing compact input:

```ruby
Amount.parse("USDC|1.50")
Amount.parse("v1:USDC|1.50")
```

Amounts serialize as compact strings in JSON:

```ruby
{ amount: Amount.of_usdc("1.50") }.to_json
# => '{"amount":"USDC|1.50"}'
```

For structured persistence or wire payloads:

```ruby
payload = Amount.of_usdc("1.50").to_h
# => { v: 1, atomic: "1500000", symbol: "USDC" }

Amount.load(payload)
```

## Lock the registry at boot

If your application configures the registry in an initializer, lock it once setup is complete:

```ruby
Amount.registry.lock!
```

That prevents accidental runtime mutation such as late registration or clearing the shared registry.

## Next steps

- Read [Atomic vs UI](/concepts/atomic-vs-ui) to understand the storage model
- Read [Rates and Conversion](/concepts/rates-and-conversion) before relying on cross-type math
- Read [Rails Overview](/rails/overview) if you want `has_amount` and `t.amount`
