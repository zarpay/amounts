# Migration DSL

Use `t.amount` to declare amount-backed columns.

## Multi-symbol amount

```ruby
t.amount :amount
```

Creates:

- `amount_atomic` as `numeric(78, 0)`
- `amount_symbol` as `string(10)`

## Fixed symbol amount

```ruby
t.amount :fee, symbol: :SOL
```

Creates:

- `fee_atomic` as `numeric(78, 0)`

## Precision override

```ruby
t.amount :reserve, precision: 40
```

Use this only when you intentionally want tighter bounds.
