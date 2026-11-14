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

### Several attributes in one query

Pass several attributes and each aggregate still runs one query, returning a Hash keyed
by attribute name in place of each Amount, as Rails' `pluck` returns rows for several
columns. A model with several amounts on one table reads them all in a single pass over
its rows, instead of one query per amount:

```ruby
UsageRecord.sum_amount(:quantity, :cost)
# => { quantity: #<Amount CALLS 13>, cost: #<Amount USDP $55.00> }

UsageRecord.group(:kind).sum_amount(:quantity, :cost)
# => { "model_call" => { quantity: #<Amount CALLS 13>,     cost: #<Amount USDP $52.00> },
#      "search"     => { quantity: #<Amount SEARCHES 3>,  cost: #<Amount USDP $3.00> } }

UsageRecord.group(:workspace_id, :kind).average_amount(:quantity, :cost, :input_tokens)
```

`minimum_amount`, `maximum_amount` and `average_amount` take several attributes the same
way. With one attribute, every method returns an Amount as before.

Each attribute is aggregated exactly as it would be alone, with the same symbol rule:
one with more than one symbol in scope, or in one group, raises `Amount::TypeMismatch`
naming it, and the whole call raises. Passing an attribute twice raises
`ArgumentError`.

How it runs: the query groups by each multi-symbol attribute's symbol column as well as
your groups, so a group whose attributes come in several symbol combinations spans
several rows. Each attribute is then combined across them, skipping the rows where it's
`NULL`: sums and counts add up, the minimum and maximum are taken across rows, and an
average divides the total sum by the total count. In the common case each attribute has
one symbol per group, and each group is one row.

**Which groups appear.** With one attribute, rows without an amount are left out
first, so a group where that attribute is always empty isn't in the result. With
several, a group appears when it has any row, and an attribute with no amount in it gets
the empty-set result from the table above:

```ruby
UsageRecord.group(:kind).sum_amount(:quantity)          # no "storage" key if no storage row has a quantity
UsageRecord.group(:kind).sum_amount(:quantity, :bytes)  # => { "storage" => { quantity: nil, bytes: #<Amount BYTES ...> }, ... }
```

::: warning SQLite
SQLite can't aggregate past 64 bits: totals of large values either raise
`integer overflow` or come back inexact. Use PostgreSQL for exact aggregates of large
values. See [Database Notes](/rails/database-notes).
:::

## Raw grouped sums

The backing columns stay queryable directly:

```ruby
Holding.group(:amount_symbol).sum(:amount_atomic)
```

That returns a low-level hash of grouped atomic sums, which the RSpec matcher
`match_amounts` reads.
