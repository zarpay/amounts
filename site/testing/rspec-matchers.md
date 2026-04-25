# RSpec Matchers

## Setup

```ruby
require "amount/rspec"
require "amount/active_record/rspec"
```

## Core matchers

```ruby
expect(Amount.usdc("1.50")).to eq_amount("USDC|1.50")
expect(Amount.usdc("1.50")).to be_amount_of(:USDC)
expect(Amount.usdc("1.50")).to be_positive_amount
expect(Amount.usdc("1.55")).to be_approximately_amount(:USDC, "1.50", within: "0.10")
```

## ActiveRecord matchers

```ruby
expect(holding).to have_amount_column(:amount, "USDC|1.50")
expect(Holding.group(:amount_symbol).sum(:amount_atomic))
  .to match_amounts(USDC: "10500.00", SOL: "12.5")
```

## When they help

These matchers are most useful when you want tests to speak in domain terms instead of backing-column details.
