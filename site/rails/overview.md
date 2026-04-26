# Rails Overview

Rails support is optional and explicit:

```ruby
require "amount/active_record"
```

The adapter adds:

- `t.amount` in migrations
- `has_amount` in models
- casting from compact strings and hash payloads
- dirty tracking and virtual change helpers
- `rails generate amounts:registry {fiat|metals|crypto|all}`

The adapter does **not** make Rails a runtime dependency of the core gem.
