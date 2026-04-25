# Timber Yard

This cookbook example focuses on discrete inventory quantities where remainder handling matters.

## Configuration

```ruby
Amount.register :LOGS,
  decimals: 0,
  display_symbol: "logs",
  display_position: :suffix,
  ui_decimals: 0
```

## Splitting an inbound shipment

```ruby
shipment = Amount.new(10, :LOGS)
parts, remainder = shipment.split(3)

parts.map(&:atomic)
# => [3, 3, 3]

remainder.atomic
# => 1
```

## Weighted allocation

```ruby
parts, remainder = Amount.new(10, :LOGS).allocate([1, 1, 2])

parts.map(&:atomic)
# => [2, 2, 5]

remainder.atomic
# => 1
```

## Negative correction

```ruby
parts, remainder = Amount.new(-10, :LOGS).split(3)
```

Negative values behave symmetrically with rounding toward zero.
