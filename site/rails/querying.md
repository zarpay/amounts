# Querying

The adapter exposes simple domain-level queries over the backing columns.

## Exact match

```ruby
Holding.where_amount("USDC|1250.00")
```

## Comparison scopes

```ruby
Holding.where_amount_gt("USDC|1000.00")
Holding.where_amount_gte("USDC|1000.00")
Holding.where_amount_lt("USDC|5000.00")
Holding.where_amount_lte("USDC|5000.00")
Holding.where_amount_between("USDC|1000.00", "USDC|5000.00")
```

Bounds are inclusive for `between`.

## Symbol filter

```ruby
Holding.amount_in(:USDC)
```

## Grouped sums

```ruby
Holding.group(:amount_symbol).sum(:amount_atomic)
```

That query returns a low-level hash of grouped atomic sums, which is why the RSpec matcher `match_amounts` can be useful in application specs.
