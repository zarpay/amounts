# Testing Overview

`amounts` supports both ordinary equality assertions and opt-in RSpec matchers.

## Minitest

You can already write:

```ruby
assert_equal Amount.of_usdc("1.50"), holding.amount
```

## RSpec

Opt in explicitly:

```ruby
require "amount/rspec"
require "amount/active_record/rspec"
```

Then write:

```ruby
expect(holding.amount).to eq_amount("USDC|1.50")
expect(holding).to have_amount_column(:amount, "USDC|1.50")
```

## Exact vs approximate

Use exact assertions for:

- equality
- persistence
- split and allocation
- registry configuration

Use approximate assertions for:

- conversion tests where small rounding windows are intentional
