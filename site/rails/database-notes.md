# Database Notes

## Default numeric precision

The migration DSL defaults to `numeric(78, 0)` for atomic columns.

That is chosen to safely cover EVM-scale integer values.

## PostgreSQL vs SQLite

### PostgreSQL

- correct target for exact large-precision storage
- should be your production database story for huge token quantities

### SQLite

- good for local integration wiring and most adapter tests
- not reliable for exact round-tripping of very large `DECIMAL(78,0)` values under ActiveRecord

## Recommended stance

Use SQLite to prove the API integration and use PostgreSQL to prove the real storage guarantee.
