# Orbit Treasury

This cookbook example follows a treasury app that tracks `USDC`, `USD`, and `SOL`.

## Configuration

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

Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"
```

## Daily uses

```ruby
operating_cash = Amount.of_usdc("250000.00")
vendor_invoice = Amount.new("7500.00", :USD)
validator_fees = Amount.of_sol("18.125")

(operating_cash - vendor_invoice).ui
validator_fees.ui
```

## Rails persistence

```ruby
class TreasuryHolding < ApplicationRecord
  has_amount :balance
end

TreasuryHolding.create!(balance: "USDC|250000.00")
```
