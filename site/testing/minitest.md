# Minitest

The gem does not ship Minitest-specific matchers because ordinary equality already works well.

## Example

```ruby
assert_equal Amount.usdc("1.50"), holding.amount
assert_equal Amount.usdc("1.50"), Amount.parse("USDC|1.50")
```

## Why this is enough

`Amount#==` already compares:

- symbol
- atomic value

That gives straightforward assertions without a second testing API surface to maintain.
