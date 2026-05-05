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

gold = Amount.of_gold("1.5")

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
Amount.of_usdc("1.567").ui
# => "$1.56"

Amount.of_usdc("1.561").ui(direction: :ceil)
# => "$1.57"
```

## Without the symbol

Pass `decorated: false` to get the rounded number on its own — useful when the currency label is rendered separately (e.g. a column header, an input adornment, a chip):

```ruby
Amount.of_usdc("1.50").ui                              # => "$1.50"
Amount.of_usdc("1.50").ui(decorated: false)            # => "1.50"

gold.ui(unit: :gram)                                # => "46.65 g"
gold.ui(unit: :gram, decorated: false)              # => "46.65"
```

`decorated: false` composes with `unit:` and `direction:` — same rounding, same display unit, just no symbol.

## Trimming trailing zeros

By default, `ui` zero-pads to the configured `ui_decimals`. For tokens with high precision, this produces verbose output like `"1.5000 SOL"`. Use `trim_zeros` to strip trailing zeros after rounding.

### Per call

```ruby
Amount.of_sol("2.5").ui(trim_zeros: true)   # => "2.5 SOL"
Amount.of_sol("1.0").ui(trim_zeros: true)   # => "1 SOL"
Amount.of_sol("1.0").ui(trim_zeros: false)  # => "1.0000 SOL"
```

### As a registry default

```ruby
Amount.register :SOL,
  decimals: 9,
  display_symbol: "SOL",
  display_position: :suffix,
  ui_decimals: 4,
  trim_zeros: true

Amount.of_sol("2.5").ui   # => "2.5 SOL"
Amount.of_sol("1.0").ui   # => "1 SOL"
```

Fiat currencies typically leave `trim_zeros` as `false` (the default) so that `$1.50` stays `$1.50`.

### Per display unit

Display units can override the registry default:

```ruby
Amount.register :GOLD,
  decimals: 8,
  trim_zeros: true,
  display_units: {
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2, trim_zeros: false }
  }
```

### Precedence

Call-site (`ui(trim_zeros:)`) > display unit spec > registry default.

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
