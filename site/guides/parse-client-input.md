# Parse Client Input

Clients usually know a symbol and a decimal value, not an atomic integer.

That is why the compact string input format exists.

## Recommended input

```text
USDC|1250.00
v1:USDC|1250.00
```

## Server-side parsing

```ruby
amount = Amount.parse(params[:balance])
```

For example:

```ruby
payload = { balance: "USDC|1250.00" }
balance = Amount.parse(payload[:balance])

balance.atomic
# => 1250000000
```

## In Rails models

If you use `has_amount`, assignment parsing already happens through the model writer:

```ruby
holding.amount = "USDC|1250.00"
```

## What not to ask from the client

Do not require:

```json
{ "atomic": "1250000000", "symbol": "USDC" }
```

unless the client is another trusted backend system and the object format is actually useful there.
