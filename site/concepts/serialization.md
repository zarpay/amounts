# Serialization

The gem has two serialization stories because real systems need two different things:

- compact human-facing strings
- stable structured payloads

## Compact string format

For clients, forms, query params, CLI input, and readable text:

```text
USDC|1.50
v1:USDC|1.50
```

Rules:

- no prefix means `v1`
- explicit `v1:` is accepted for forward compatibility
- the amount part is a UI decimal value
- the client does not need to know atomic units

## Structured payload format

For persistence and language-safe wire payloads:

```ruby
Amount.usdc("1.50").to_h
# => { v: 1, atomic: "1500000", symbol: "USDC" }
```

This is the canonical structured format because it is:

- explicit
- versioned
- safe for very large integers
- stable across languages

## Orbit Treasury example

```ruby
incoming = "v1:USDC|1250.00"
amount = Amount.parse(incoming)

amount.to_h
# => { v: 1, atomic: "1250000000", symbol: "USDC" }
```

## What to use where

| Use case | Recommended format |
| --- | --- |
| Browser form field | `USDC|1.50` |
| CLI or admin tooling | `USDC|1.50` |
| Internal JSON API object | `{ v: 1, atomic: "1500000", symbol: "USDC" }` |
| Database persistence | atomic + symbol columns |

## Common mistake

::: warning
Do not treat `to_s` as the long-term structured API contract. It is the compact parseable string. The structured hash payload is the canonical serialized form.
:::

## See also

- [Parse Client Input](/guides/parse-client-input)
- [Atomic vs UI](/concepts/atomic-vs-ui)
