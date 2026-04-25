---
layout: home
hero:
  name: amounts
  text: Precise fungible quantities for Ruby and Rails
  tagline: One abstraction for money, tokens, commodities, inventory, and points — with atomic integer storage, registry-driven type safety, optional Rails persistence, and explicit conversion rules.
  actions:
    - theme: brand
      text: Start with Quick Start
      link: /getting-started/
    - theme: alt
      text: Learn the Concepts
      link: /concepts/atomic-vs-ui
---

## What this gem is for

`amounts` is for applications that need to answer questions like:

- How much USDC is in this treasury wallet?
- How much gold is in this vault?
- How many logs are left in this inventory split?
- How do I store all of that in Rails without losing precision?

The gem treats all of those as the same core problem: a precise quantity of a registered fungible type.

## The three running examples

The docs stay grounded in three recurring examples:

- **Orbit Treasury**: a crypto and fiat treasury using `USDC`, `USD`, and `SOL`
- **Auric Vault**: a metals ledger using `GOLD` with display units like grams and kilograms
- **Timber Yard**: an inventory workflow using `LOGS` for split and allocation examples

Those examples reappear across concepts, guides, Rails integration, and testing so the ideas build instead of resetting on every page.

## A five-minute example

```ruby
require "amount"

Amount.register :USDC,
  decimals: 6,
  display_symbol: "$",
  display_position: :prefix,
  ui_decimals: 2

Amount.register :USD,
  decimals: 2,
  display_symbol: "$",
  display_position: :prefix,
  ui_decimals: 2

Amount.register :SOL,
  decimals: 9,
  display_symbol: "SOL",
  display_position: :suffix,
  ui_decimals: 4

Amount.register_default_rate :USD, :USDC, "1"

Amount.register_default_rate :USDC, :USD, "1"

payroll_buffer = Amount.usdc("125000.00")
invoice = Amount.new("2500.00", :USD)

(payroll_buffer - invoice).ui
# => "$122500.00"
```

## What matters most about the model

| Concern | `amounts` answer |
| --- | --- |
| Precision | Every amount stores atomic value as a Ruby `Integer` |
| Type identity | Types live in a registry, not a class hierarchy |
| Cross-type math | Allowed only when a directional rate exists |
| Display units | Scale presentation, not type conversion |
| Splits | Return `[parts, remainder]`, never implicit favoritism |
| Rails | Optional adapter, not a core runtime dependency |

## How to read the docs

- **Quick Start** gets one example working end-to-end.
- **Concepts** explains the mental model behind the API.
- **Guides** solve concrete jobs without assuming Rails.
- **Rails** covers migrations, models, querying, and database behavior.
- **Testing** shows how to test exact and approximate expectations.
- **Cookbook** collects longer real-world patterns.
- **Design** explains the tradeoffs and comparisons honestly.
- **[CHANGELOG](https://github.com/zarpay/amounts/blob/main/CHANGELOG.md)** lists what changed in each release.

## Where people usually go wrong

::: warning Common misread
The gem has a few deliberate distinctions that matter:

- atomic values are internal storage, not display values
- display units are not real type conversions
- `split` and `allocate` expose remainder explicitly
- rates are directional and never inferred in reverse
:::

Those points are what make the abstraction reliable. The Concepts section is designed to make them feel obvious before you reach for the API reference.
