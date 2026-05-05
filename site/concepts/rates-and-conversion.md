# Rates and Conversion

Cross-type arithmetic is allowed, but only when the application has defined how conversion should work.

## The rule

For `+`, `-`, and `<=>`:

- same-type operations work directly
- cross-type operations convert the **right-hand side into the left-hand side**
- conversion only happens when a directional rate exists

## Orbit Treasury example

```ruby
Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"

usdc = Amount.of_usdc("10.00")
usd = Amount.new("5.00", :USD)

usdc + usd
# => #<Amount USDC $15.00>

usd + usdc
# => #<Amount USD $15.00>
```

The direction matters:

- `usdc + usd` needs `USD -> USDC`
- `usd + usdc` needs `USDC -> USD`

## Why directional?

Real systems often do not have symmetric conversions:

- bid/ask spreads
- fees
- inventory pricing rules
- manual accounting rates

So the gem never assumes reverse conversion exists just because forward conversion does.

## Explicit conversion

You can also convert directly:

```ruby
Amount.of_usdc("1000").to(:GOLD, rate: "0.00042")
```

That is useful for one-off operations without touching the default registry rates.

## What the gem intentionally does not do

It does **not**:

- fetch rates
- build rate graphs
- find multi-hop paths
- decide which market source is authoritative

Those are application concerns.

## Common mistake

::: warning
If you see `Amount::TypeMismatch` on cross-type arithmetic, the fix is not “make the gem smarter.” The fix is to either:

- register the directional rate you need, or
- convert explicitly with `.to(..., rate: ...)`
:::

## See also

- [Cross-Type Arithmetic Guide](/guides/cross-type-arithmetic)
- [Compared to Alternatives](/design/comparisons)
