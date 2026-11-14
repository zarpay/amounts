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

## Aggregates

`sum_amount`, `minimum_amount`, `maximum_amount` and `average_amount` run in SQL
and return Amounts. Each is one query, in the scope of the relation it's called on,
so `where`, `group` and associations apply:

```ruby
Holding.sum_amount(:fee)                          # => #<Amount SOL ...>
Holding.where_amount_gt("USDC|100").maximum_amount(:amount)
holding.transfers.sum_amount(:commission)         # one holding's total
Holding.group(:account_id).average_amount(:fee)   # => { 1 => #<Amount SOL ...>, ... }
```

Grouped, the result is keyed like Rails' `group(...).sum`: by the group's value, or by
an array of values for several groups. Group by a column or SQL expression. Grouping by
an association name (`group(:account)`) raises `ArgumentError`; group by its foreign
key instead.

### Symbols never mix

A fixed-symbol attribute always aggregates to its symbol. A multi-symbol attribute
aggregates only when a single symbol is in scope; with more than one, in scope or in one
group, it raises `Amount::TypeMismatch`, as `+` would. Group by the symbol column for one
Amount per symbol:

```ruby
Holding.sum_amount(:amount)                          # raises if USDC and SOL rows are in scope
Holding.amount_in(:USDC).sum_amount(:amount)         # => #<Amount USDC ...>
Holding.group(:amount_symbol).sum_amount(:amount)    # => { "USDC" => #<Amount USDC ...>, "SOL" => #<Amount SOL ...> }
```

### Empty sets and averages

| | Over no rows |
|---|---|
| `sum_amount`, fixed symbol | zero of that symbol, like Rails' `sum` |
| `sum_amount`, multi-symbol | `nil` (there's no symbol to make a zero in) |
| `minimum_amount`, `maximum_amount`, `average_amount` | `nil` |

`average_amount` divides the sum by the number of amounts, both from the same query, and
truncates toward zero to a whole atomic unit, as `Amount#/` does. Rows without an amount
are not counted.

::: warning SQLite
SQLite returns sums past 64 bits inexactly. Use PostgreSQL for exact aggregates of large
values. See [Database Notes](/rails/database-notes).
:::

## Raw grouped sums

The backing columns stay queryable directly:

```ruby
Holding.group(:amount_symbol).sum(:amount_atomic)
```

That returns a low-level hash of grouped atomic sums, which the RSpec matcher
`match_amounts` reads.
