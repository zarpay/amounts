# Cross-Type Arithmetic

This guide shows how to make cross-type arithmetic safe without turning the gem into a rate engine.

## Orbit Treasury example

```ruby
Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"

payroll_buffer = Amount.usdc("100000.00")
invoice = Amount.new("2500.00", :USD)

(payroll_buffer - invoice).ui
# => "$97500.00"
```

## How it works

`payroll_buffer - invoice` converts `invoice` from `USD` into `USDC` because the right-hand side is converted into the left-hand side’s type.

## Failing intentionally

```ruby
Amount.usdc("10.00") + Amount.sol("1.00")
# => raises Amount::TypeMismatch
```

This is a feature, not a missing convenience.

## Use explicit conversion when the rate is one-off

```ruby
gold = Amount.gold("1.0")
quoted = Amount.usdc("1000.00").to(:GOLD, rate: "0.00042")

gold + quoted
```
