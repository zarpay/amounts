# Atomic vs UI

This is the most important idea in the gem.

## The rule

Every `Amount` stores one canonical value:

- `atomic` is an `Integer`
- it represents the smallest unit of the registered type
- it is the exact value used for equality, hashing, math, and persistence

UI values are just a human-facing decimal view on top of that atomic integer.

## Orbit Treasury example

```ruby
Amount.register :USDC, decimals: 6

balance = Amount.usdc("1.50")

balance.atomic
# => 1500000

balance.decimal.to_s("F")
# => "1.5"
```

Both numbers represent the same value:

- `1500000` is storage-safe and exact
- `1.5` is readable and convenient

## Why this matters

If the atomic value were a decimal instead of an integer, the library would lose some of the guarantees it is trying to provide:

- exact hashing and equality get fuzzier
- persistence becomes less obviously canonical
- “smallest indivisible unit” stops meaning anything crisp

The gem solves that by making the atomic value the single source of truth.

## Input inference

```ruby
Amount.usdc(1_500_000)                # atomic
Amount.usdc("1.50")                   # UI
Amount.usdc(1.5)                      # UI
Amount.usdc(BigDecimal("1.5"))        # UI
Amount.usdc(1_500_000, from: :atomic) # explicit atomic
```

## Client/server boundary

In most real systems:

- clients know UI values
- servers store atomic values

That means a client usually sends:

```text
USDC|1.50
```

and the server turns that into:

```ruby
{ v: 1, atomic: "1500000", symbol: "USDC" }
```

## Common mistake

::: warning Do not make the client think in atomic units
The compact client string format is decimal and symbol based on purpose. A browser or mobile client should not need to know that `1.50 USDC` means `1500000` atomic units.
:::

## See also

- [Serialization](/concepts/serialization)
- [Display and Units](/concepts/display-and-units)
- [Rails Persistence](/guides/rails-persistence)
