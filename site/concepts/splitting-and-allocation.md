# Splitting and Allocation

Division, splitting, and allocation are three different operations.

## Division

Scalar division gives you one scaled amount:

```ruby
Amount.of_usdc("10.00") / 2
# => #<Amount USDC $5.00>
```

That is not the same thing as “split this amount into two parts.”

## Timber Yard example

```ruby
Amount.register :LOGS,
  decimals: 0,
  display_symbol: "logs",
  display_position: :suffix,
  ui_decimals: 0

shipment = Amount.new(10, :LOGS)
parts, remainder = shipment.split(3)

parts.map(&:atomic)
# => [3, 3, 3]

remainder.atomic
# => 1
```

The remainder is explicit on purpose.

## Allocation

Weighted allocation uses integer weights:

```ruby
parts, remainder = Amount.new(10, :LOGS).allocate([1, 1, 2])

parts.map(&:atomic)
# => [2, 2, 5]

remainder.atomic
# => 1
```

## Negative values

Negative splitting and allocation follow the same model with rounding toward zero:

```ruby
parts, remainder = Amount.new(-10, :LOGS).split(3)

parts.map(&:atomic)
# => [-3, -3, -3]

remainder.atomic
# => -1
```

## Invariant

This is the contract:

```ruby
parts.sum(&:atomic) + remainder.atomic == original.atomic
```

Always.

## Common mistake

::: warning
The gem does not silently distribute remainder to the first recipients. That behavior is intentionally rejected because it hides a business decision.
:::

## See also

- [Timber Yard Cookbook](/cookbook/timber-yard)
