# Display and Units

Display units are presentation helpers, not real type conversions.

## Auric Vault example

```ruby
Amount.register :GOLD,
  decimals: 8,
  display_symbol: "oz t",
  display_position: :suffix,
  ui_decimals: 4,
  display_units: {
    oz_t: { scale: 1, symbol: "oz t", ui_decimals: 4 },
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2 },
    kg:   { scale: "0.0311035", symbol: "kg", ui_decimals: 5 }
  }

gold = Amount.gold("1.5")

gold.ui
# => "1.5000 oz t"

gold.ui(unit: :gram)
# => "46.65 g"
```

The value is still `:GOLD`.

## The three display APIs

```ruby
gold.formatted      # exact storage decimals
gold.ui             # default display style
gold.in_unit(:gram) # raw BigDecimal in a display unit
```

## Rounding direction

`ui` uses directional truncation:

```ruby
Amount.usdc("1.567").ui
# => "$1.56"

Amount.usdc("1.561").ui(direction: :ceil)
# => "$1.57"
```

## Without the symbol

Pass `decorated: false` to get the rounded number on its own — useful when the currency label is rendered separately (e.g. a column header, an input adornment, a chip):

```ruby
Amount.usdc("1.50").ui                              # => "$1.50"
Amount.usdc("1.50").ui(decorated: false)            # => "1.50"

gold.ui(unit: :gram)                                # => "46.65 g"
gold.ui(unit: :gram, decorated: false)              # => "46.65"
```

`decorated: false` composes with `unit:` and `direction:` — same rounding, same display unit, just no symbol.

## What display units are not

They are not:

- alternate storage types
- a second registry entry
- a conversion from gold to grams as a new fungible symbol

They are just scaled renderings of the same underlying amount.

## Common mistake

::: warning
`gold.ui(unit: :gram)` does not mean “this amount has become grams.” It means “show this gold amount in grams for presentation.”
:::

## See also

- [Atomic vs UI](/concepts/atomic-vs-ui)
- [Auric Vault Cookbook](/cookbook/auric-vault)
