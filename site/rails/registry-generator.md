# Registry Generator

If you want a Rails initializer seeded with common type registrations, generate one:

```bash
bin/rails generate amounts:registry fiat
bin/rails generate amounts:registry metals
bin/rails generate amounts:registry crypto
bin/rails generate amounts:registry all
```

That writes `config/initializers/amounts.rb` with curated `Amount.register` calls.

## What each preset contains

- `fiat`: a basket of major fiat currencies with appropriate display symbols and UI decimals
- `metals`: precious and industrial metals, including display units for troy-ounce and kilogram-style presentation
- `crypto`: a basket of major crypto assets and stablecoins, including unit helpers such as satoshis, gwei, and lamports where useful
- `all`: the union of the three presets with duplicate symbols removed

## What the generator does not do

It does **not** register default rates.

That is intentional because rates are directional and application-specific:

```ruby
Amount.register_default_rate :USD, :USDC, "1"
Amount.register_default_rate :USDC, :USD, "1"
```

Add only the pairs your application actually means.
