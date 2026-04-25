# Rails Persistence

This guide uses **Orbit Treasury** holdings to show how the optional Rails layer maps one logical amount onto one or two database columns.

## Migration

```ruby
create_table :holdings do |t|
  t.amount :amount
  t.amount :fee, symbol: :SOL
end
```

That creates:

- `amount_atomic`
- `amount_symbol`
- `fee_atomic`

## Model

```ruby
class Holding < ApplicationRecord
  has_amount :amount
  has_amount :fee, symbol: :SOL
end
```

## Assignment

```ruby
holding = Holding.new
holding.amount = "USDC|1250.00"
holding.fee = 0.25
```

## Querying

```ruby
Holding.where_amount("USDC|1250.00")
Holding.where_amount_gt("USDC|1000.00")
Holding.where_amount_between("USDC|1000.00", "USDC|5000.00")
Holding.amount_in(:USDC)
Holding.group(:amount_symbol).sum(:amount_atomic)
```

## Important note

Use PostgreSQL for true large-precision numeric guarantees. SQLite is good enough for integration wiring, but not for huge `numeric(78,0)` round trips.
