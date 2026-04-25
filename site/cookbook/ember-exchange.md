# Ember Exchange

This cookbook example is intentionally more dynamic than the others.

It models:

- a fictional in-game currency called `EMBER`
- real `USD` with coin-style display units
- vaulted `SILVER` with ounce, gram, and kilogram displays
- directional rates that let the same value move across all three domains

The point is not realism. The point is to show how much variation the same `Amount` model can hold without changing abstractions.

## Configuration

```ruby
Amount.register :EMBER,
  decimals: 2,
  display_symbol: "embers",
  display_position: :suffix,
  ui_decimals: 2,
  display_units: {
    ember: { scale: 1, symbol: "embers", ui_decimals: 2 },
    spark: { scale: 100, symbol: "sparks", ui_decimals: 0 }
  },
  default_display: :ember

Amount.register :USD,
  decimals: 2,
  display_symbol: "$",
  display_position: :prefix,
  ui_decimals: 2,
  display_units: {
    dollar:  { scale: 1, symbol: "$", position: :prefix, ui_decimals: 2 },
    cent:    { scale: 100, symbol: "cents", position: :suffix, ui_decimals: 0 },
    nickel:  { scale: 20, symbol: "nickels", position: :suffix, ui_decimals: 0 },
    dime:    { scale: 10, symbol: "dimes", position: :suffix, ui_decimals: 0 },
    quarter: { scale: 4, symbol: "quarters", position: :suffix, ui_decimals: 2 }
  },
  default_display: :dollar

Amount.register :SILVER,
  decimals: 8,
  display_symbol: "oz t",
  display_position: :suffix,
  ui_decimals: 4,
  display_units: {
    oz_t: { scale: 1, symbol: "oz t", ui_decimals: 4 },
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2 },
    kg:   { scale: "0.0311035", symbol: "kg", ui_decimals: 5 }
  },
  default_display: :oz_t

Amount.register_default_rate :EMBER, :USD, "0.125"

Amount.register_default_rate :USD, :EMBER, "8"

Amount.register_default_rate :SILVER, :USD, "28.40"

Amount.register_default_rate :USD, :SILVER, "0.0352112676"
```

In this fictional market:

- `1 EMBER` is worth `$0.125`
- `$1.00` buys `8 EMBER`
- `1 SILVER` is worth `$28.40`

## The same value in different displays

```ruby
raid_reward = Amount.ember("480.00")
merchant_cash = Amount.usd("24.65")
vaulted_silver = Amount.silver("18.75")
```

The game reward stays in fictional units:

```ruby
raid_reward.ui
# => "480.00 embers"

raid_reward.ui(unit: :spark)
# => "48000 sparks"
```

The cash stays in dollars, but can be shown in familiar coin displays:

```ruby
merchant_cash.ui
# => "$24.65"

merchant_cash.ui(unit: :cent)
# => "2465 cents"

merchant_cash.ui(unit: :nickel)
# => "493 nickels"

merchant_cash.ui(unit: :dime)
# => "246 dimes"

merchant_cash.ui(unit: :quarter)
# => "98.60 quarters"
```

The metal position is still silver, just shown in different display units:

```ruby
vaulted_silver.ui
# => "18.7500 oz t"

vaulted_silver.ui(unit: :gram)
# => "583.19 g"

vaulted_silver.ui(unit: :kg)
# => "0.58319 kg"
```

## Cross-type arithmetic through registered rates

Because directional rates are registered, you can mix them explicitly but safely.

Adding cash to the game reward keeps the left-hand type:

```ruby
(raid_reward + merchant_cash).ui
# => "677.20 embers"
```

Going the other direction keeps dollars:

```ruby
(merchant_cash + raid_reward).ui
# => "$84.65"
```

Commodity math works the same way:

```ruby
(vaulted_silver + merchant_cash).ui
# => "19.6179 oz t"

(merchant_cash + vaulted_silver).ui
# => "$557.15"
```

## A fuller exchange flow

Imagine a player cashes out some embers, then buys physical silver with part of the proceeds:

```ruby
player_wallet = Amount.ember("960.00")
cash_out = Amount.ember("320.00").to(:USD)
silver_purchase = Amount.usd("50.00").to(:SILVER)
```

That gives:

```ruby
player_wallet.ui
# => "960.00 embers"

cash_out.ui
# => "$40.00"

silver_purchase.ui
# => "1.7605 oz t"
```

And those same values can still be shown in different displays:

```ruby
cash_out.ui(unit: :quarter)
# => "160.00 quarters"

silver_purchase.ui(unit: :gram)
# => "54.75 g"
```

## Why this example matters

This is one abstraction handling:

- fictional game money
- fiat display conventions
- commodity display conventions
- explicit directional conversion
- safe cross-type arithmetic

without introducing a second value object or a separate unit system.
