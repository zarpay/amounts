# has_amount

`has_amount` exposes two or more physical columns as one logical amount attribute.

## Example

```ruby
class Holding < ApplicationRecord
  has_amount :amount
  has_amount :fee, symbol: :SOL
end
```

## What the writer accepts

For multi-symbol attributes:

- `Amount`
- compact string like `"USDC|1.50"`
- hash payloads

For fixed-symbol attributes:

- all of the above
- raw numerics such as `0.25`

## Dirty tracking helpers

```ruby
holding.amount_changed?
holding.amount_change
holding.saved_change_to_amount?
holding.amount_before_last_save
```
