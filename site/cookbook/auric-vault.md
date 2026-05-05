# Auric Vault

This cookbook example tracks vaulted gold while showing it in multiple display units.

## Configuration

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
```

## Displaying the same amount differently

```ruby
vault_position = Amount.of_gold("12.75")

vault_position.ui
# => "12.7500 oz t"

vault_position.ui(unit: :gram)
# => "396.57 g"

vault_position.ui(unit: :kg)
# => "0.39657 kg"
```

## Converting from USDC using an explicit quote

```ruby
quoted_gold = Amount.of_usdc("1000.00").to(:GOLD, rate: "0.00042")
quoted_gold.ui
```
