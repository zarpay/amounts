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

## Validation messages

`validates :amount, amount: { symbol: :USDC, greater_than: 0 }` adds errors by
I18n key, so apps can translate or reword them. The English defaults ship in
`lib/amount/active_record/locale/en.yml`, which the gem adds to `I18n.load_path`
when `amount/active_record` loads (Rails or plain ActiveRecord).

| Case | Key | Interpolations | English default |
|---|---|---|---|
| Not an Amount | `:amount_type` | | `must be an Amount` |
| Wrong symbol | `:amount_symbol` | `expected` | `must have symbol %{expected}` |
| Invalid constraint | `:amount_invalid_constraint` | `option`, `message` | `has invalid %{option} constraint: %{message}` |
| Incomparable | `:amount_incomparable` | `symbol`, `other_symbol`, `option` | `cannot compare %{symbol} to %{other_symbol} for %{option}` |
| Comparisons | Rails' `:greater_than`, `:greater_than_or_equal_to`, `:less_than`, `:less_than_or_equal_to` | `count` (the other amount's `to_s`) | Rails' own, e.g. `must be greater than %{count}` |
| Fallback | Rails' `:invalid` | | `is invalid` |

Override any of them in your own locale files:

```yaml
de:
  errors:
    messages:
      amount_symbol: "muss das Symbol %{expected} haben"
```

`record.errors.details` reports the keys and interpolation values.
Apps that already translate Rails' `greater_than` etc. get those translations
for free.
