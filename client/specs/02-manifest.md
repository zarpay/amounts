# 02 — The manifest

**The manifest is the registry, written as JSON.** The gem produces it
(`Amount.manifest`) and the client consumes it (`Amounts.fromManifest`).
It carries everything the core reads at runtime, and nothing the core
doesn't: no Ruby classes, no I18n keys, no options the core ignores.

## Producing it

```ruby
Amount.manifest                      # types and rates, no locales
Amount.manifest(locales: %i[en de])  # plus the tables for each locale (needs I18n)
```

It returns a `Hash` with String keys, ready for `to_json`. A Rails app
typically serves it from a controller, or writes it to a file at build time
for the frontend to import:

```ruby
render json: Amount.manifest(locales: I18n.available_locales)
```

## Shape

```json
{
  "v": 1,
  "types": {
    "USDC": {
      "decimals": 6,
      "display_symbol": "$",
      "display_format": "%u%n",
      "ui_decimals": 2,
      "trim_zeros": false,
      "display_units": null,
      "default_display": null
    },
    "GOLD": {
      "decimals": 8,
      "display_symbol": "oz t",
      "display_format": "%n %u",
      "ui_decimals": 4,
      "trim_zeros": false,
      "display_units": {
        "gram": {
          "scale": "31.1034768",
          "symbol": "g",
          "ui_decimals": 2,
          "format": null,
          "trim_zeros": null
        }
      },
      "default_display": "oz_t"
    }
  },
  "rates": [{ "from": "USD", "to": "USDC", "rate": "1.0" }],
  "locales": {
    "de": {
      "number": { "delimiter": ".", "separator": "," },
      "compact": {
        "format": "%n %u",
        "units": { "thousand": "Tsd.", "million": { "one": "Mio.", "other": "Mio." } }
      },
      "types": {
        "USD": { "label": null, "format": "%n %u", "units": {} },
        "GOLD": { "label": "Feinunze", "format": null, "units": { "gram": { "label": "Gramm", "format": null } } }
      }
    }
  }
}
```

### `v`

The manifest format version, `1`. The client refuses any other version
(`INVALID_MANIFEST`), so a gem that changes the shape bumps it rather than
having old clients misread a new manifest.

### `types`

One entry per registered symbol, keyed by the symbol. Keys are the
`Amount.register` option names, so the manifest reads like the initializer:

| Key               | Value                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------- |
| `decimals`        | storage decimals                                                                       |
| `display_symbol`  | a String, or a plural Hash (`{ "one": "search", "other": "searches" }`)                |
| `display_format`  | the resolved template. `display_position` is not written: the registry already turned it into this template |
| `ui_decimals`     | default display decimals                                                               |
| `trim_zeros`      | `true` / `false`                                                                       |
| `display_units`   | `null`, or one entry per unit (below)                                                  |
| `default_display` | the unit key, or `null`. Stored, as in the registry; nothing in the core reads it      |

A display unit:

| Key           | Value                                                                                  |
| ------------- | -------------------------------------------------------------------------------------- |
| `scale`       | exact decimal String (`coerce_decimal(scale).to_s("F")`), so a `Rational` scale crosses exactly as the gem uses it |
| `symbol`      | String, plural Hash, or `null` (falls back to the type's `display_symbol`)             |
| `ui_decimals` | Integer or `null` (falls back to the type's)                                           |
| `format`      | the unit's `:format`, else the template its `:position` stands for, else `null`        |
| `trim_zeros`  | `true` / `false`, or `null` when the unit doesn't set it (falls back to the type's)    |

A unit's `label_key` is not written: it is an I18n key, resolved into
`locales` below.

### `rates`

Every registered default rate, directional, as an exact decimal String
(`BigDecimal#to_s("F")`). The client never inverts one, just as the gem
doesn't.

### `locales`

Present only for the locales asked for (`{}` otherwise). Each table holds
the result of every I18n lookup the core makes for that locale, already
resolved — so the client needs neither I18n nor the key conventions:

| Key                              | Resolved from                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------- |
| `number`                         | `number.format.delimiter` / `.separator`, with the gem's defaults (`,` / `.`) |
| `compact.format`                 | `number.human.decimal_units.format`, if it places `%n`, else `"%n %u"`        |
| `compact.units.<scale>`          | `number.human.decimal_units.units.<scale>` (String, plural Hash, or `null`)   |
| `types.<SYM>.label`              | the type's `label_key`, else `amounts.units.<sym>` — raw: String, plural Hash, or `null` |
| `types.<SYM>.format`             | `amounts.formats.<sym>`, if it places `%n`, else `null`                       |
| `types.<SYM>.units.<unit>.label` | the unit's `label_key`, else `amounts.display_units.<sym>.<unit>`, or `null`  |
| `types.<SYM>.units.<unit>.format`| `amounts.display_unit_formats.<sym>.<unit>`, if it places `%n`, else `null`   |

Labels stay raw (a plural Hash is written whole) because the form is chosen
at display time, from the number being displayed. The fallbacks — a `null`
label falls back to `display_symbol`, a `null` format to the registered
template — are applied by the client exactly as the gem applies them, so
they are not written twice.

## Validation

The client validates on construction and refuses a malformed manifest with
`INVALID_MANIFEST`, naming the path (`types.USDC.decimals`). A manifest
that constructs is complete: no later call fails on a missing key.
