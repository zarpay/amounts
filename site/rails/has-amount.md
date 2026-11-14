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

`amount_changes` and `saved_amount_changes` are Rails' `changes` and `saved_changes`
with each amount by name, as `[before, after]` Amounts, in place of its columns:

```ruby
holding.update!(amount: "USDC|11.25")

holding.saved_amount_changes
# => { "amount" => [#<Amount USDC $10.00>, #<Amount USDC $11.25>], "updated_at" => [...] }

holding.saved_changes
# => { "amount_atomic" => [10000000, 11250000], "updated_at" => [...] }
```

Rails' own `changes`, `saved_changes` and `previous_changes` stay keyed by column,
so code and gems that read them by column (audit trails, change logs) keep working.

## JSON

`as_json`, `to_json` and `serializable_hash` write each amount by its name, as its exact
compact string, in place of its columns:

```ruby
holding.as_json
# => { "id" => 1, "amount" => "USDC|10.000000", "fee" => "SOL|0.250000000", ... }

holding.as_json(only: :amount)        # => { "amount" => "USDC|10.000000" }
holding.as_json(except: :fee)         # every key but fee
holding.as_json(amounts: false)       # => { "id" => 1, "amount_atomic" => 10000000, "amount_symbol" => "USDC", ... }
```

- `only:` and `except:` take the amount's name.
- `amounts: false` writes the columns instead, for that one call. Inside `include:`, it
  applies to the included records.
- An amount whose columns weren't all selected (`select(:id, :amount_atomic)`) keeps
  the columns that were.
- `serializable_hash` holds the Amount itself, and `as_json` turns it into the string.

Only models that declare `has_amount` get this behaviour. `has_amount` includes it into
the model, and `ActiveRecord::Base` is left alone.

## Bulk writes

`insert_all`, `upsert_all` and their variants skip attribute writers and take column
values only. `amount_column_values` turns attributes, with amounts by name, into those
column values:

```ruby
Holding.amount_column_values(amount: "USDC|1.50", fee: 0.25, memo: "opening")
# => { "amount_atomic" => 1500000, "amount_symbol" => "USDC", "fee_atomic" => 250000000, memo: "opening" }

Holding.insert_all(rows.map { |row| Holding.amount_column_values(row) })
GoldBar.upsert_all(manifest.map { |row| GoldBar.amount_column_values(row) }, unique_by: :serial)
```

- Each amount is cast as its writer would cast it, and replaced by its component
  columns. Other keys pass through unchanged.
- A `nil` amount still gives all of its columns, as `nil`. `insert_all` needs every row to
  have the same keys, so pass `amount: nil` instead of leaving the key out.
- Bulk writes skip validations, so a fixed-symbol amount in another symbol raises
  `Amount::TypeMismatch` here. The writer records it as a validation error instead.
- `unique_by:`, `update_only:` and `on_duplicate:` still name columns
  (`amount_atomic`), not amounts.

## Subclasses and STI

A subclass inherits its parent's amounts, with their readers, writers, scopes,
validations and introspection. Amounts a subclass declares are its own: the
parent and its other subclasses don't see them.

```ruby
class Transfer < ApplicationRecord
  has_amount :gross
  has_amount :commission, symbol: :USDC
end

class WireTransfer < Transfer
  has_amount :wire_fee, symbol: :USDC
end

WireTransfer.amount_attribute_definitions.keys  # => [:gross, :commission, :wire_fee]
Transfer.amount_attribute_definitions.keys      # => [:gross, :commission]
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
