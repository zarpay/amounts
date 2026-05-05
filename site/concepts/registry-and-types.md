# Registry and Types

`amounts` uses one `Amount` class and a registry of type definitions.

That is deliberate.

## The model

Type identity lives in data:

```ruby
Amount.register :USDC, decimals: 6

Amount.register :GOLD, decimals: 8
```

An amount’s symbol determines:

- storage precision
- default formatting (including `trim_zeros`)
- display units
- custom amount subclass, if any
- whether a convenience constructor can be generated

## Generated constructors

When a registered symbol downcases to a valid Ruby method name, the registry generates a convenience constructor on `Amount` with an `of_` prefix:

```ruby
Amount.of_usdc("1.50")
Amount.of_gold("2.5")
```

The prefix avoids collisions with methods that already exist on `Object` — `try`, `then`, `tap`, `send`, `display`, `format`, and similar names that ActiveSupport or Ruby core already define. Without it, `:TRY` (Turkish Lira) would be unregistrable in any Rails app.

This is just ergonomic sugar on top of:

```ruby
Amount.new("1.50", :USDC)
Amount.new("2.5", :GOLD)
```

## Custom classes

Sometimes a type wants extra behavior:

```ruby
class GoldAmount < Amount
  def purity_estimate
    "24k"
  end
end

Amount.register :GOLD,
  decimals: 8,
  class: GoldAmount

Amount.of_gold("1.0").class
# => GoldAmount
```

`Amount.new("1.0", :GOLD)` returns a `GoldAmount` too — when a symbol is registered with `class:`, every entry point that knows the symbol at runtime (`Amount.new`, `Amount.parse`, `Amount.load`, the ActiveRecord adapter) dispatches to the registered subclass. Direct calls to a different subclass (`OtherAmount.new(value, :GOLD)`) still raise `Amount::InvalidInput`.

The type is still registry-driven. The subclass is an escape hatch, not the primary model.

## Locking the registry

For real applications, registry configuration is usually boot-time setup:

```ruby
Amount.register :USDC, decimals: 6

Amount.register :USD, decimals: 2

Amount.registry.lock!
```

After that, mutation raises:

- further `register`
- further `register_default_rate`
- `clear!`

## Why not one class per type?

Because the useful extension point is configuration, not inheritance.

Adding a new type should feel like:

```ruby
Amount.register :LOYALTY_POINTS, decimals: 0
```

not:

```ruby
class LoyaltyPointsAmount < Amount
end
```

## Common mistake

::: warning Do not read `Amount.of_usdc(...)` as “USDC is a class”
`Amount.of_usdc(...)` is a generated class method, not a type constant. The actual type identity is still the registered symbol `:USDC`.
:::

## See also

- [Rates and Conversion](/concepts/rates-and-conversion)
- [Design Decisions](/design/decisions)
