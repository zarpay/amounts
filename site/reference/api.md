# API Reference

The API reference in this site is intentionally short and task-oriented. For generated YARD output in the repository, see the `doc/` directory or run:

```bash
bundle exec yard doc
```

## Core types

- `Amount`
- `Amount::Registry`
- `Amount::Display`

## Optional integrations

- `Amount::ActiveRecord`
- `Amount::ActiveRecord::Type`

## Compact string APIs

- `Amount.parse`
- `Amount#to_s`
- `Amount#as_json` / `Amount#to_json`

## Structured payload APIs

- `Amount#to_h`
- `Amount.load`

## RSpec integrations

- `eq_amount`
- `be_amount_of`
- `be_zero_amount`
- `be_positive_amount`
- `be_negative_amount`
- `be_approximately_amount`
- `have_amount_column`
- `match_amounts`
