# Register a Token

This guide uses **Orbit Treasury** to register `USDC`, `USD`, and `SOL` cleanly.

## Goal

Set up types so that:

- storage precision is correct
- default display is readable
- convenience constructors exist
- cross-type arithmetic can be enabled later

## Register the base types

```ruby
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
```

## Use the generated constructors

```ruby
Amount.usdc("1250.00")
Amount.sol("0.125")
```

## Add rates only when you mean it

```ruby
Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"
```

Do not register both directions unless your application really means both directions.

## Lock after boot

```ruby
Amount.registry.lock!
```

That prevents late mutation in development consoles, jobs, or application runtime.
