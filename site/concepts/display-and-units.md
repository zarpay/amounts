# Display and Units

Display units are presentation helpers, not real type conversions.

## Auric Vault example

```ruby
Amount.register :GOLD,
  decimals: 8,
  display_symbol: "oz t",
  display_position: :suffix,
  ui_decimals: 4,
  display_units: {
    oz_t: { scale: 1, symbol: "oz t", ui_decimals: 4 },
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2 },
    kg:   { scale: "0.0311035", symbol: "kg", ui_decimals: 5 }
  }

gold = Amount.of_gold("1.5")

gold.ui
# => "1.5000 oz t"

gold.ui(unit: :gram)
# => "46.65 g"
```

The value is still `:GOLD`.

## The three display APIs

```ruby
gold.formatted      # exact storage decimals
gold.ui             # default display style
gold.in_unit(:gram) # raw BigDecimal in a display unit
```

## Rounding direction

`ui` uses directional truncation:

```ruby
Amount.of_usdc("1.567").ui
# => "$1.56"

Amount.of_usdc("1.561").ui(direction: :ceil)
# => "$1.57"
```

## Without the symbol

Pass `decorated: false` to get the rounded number on its own — useful when the currency label is rendered separately (e.g. a column header, an input adornment, a chip):

```ruby
Amount.of_usdc("1.50").ui                              # => "$1.50"
Amount.of_usdc("1.50").ui(decorated: false)            # => "1.50"

gold.ui(unit: :gram)                                # => "46.65 g"
gold.ui(unit: :gram, decorated: false)              # => "46.65"
```

`decorated: false` composes with `unit:` and `direction:` — same rounding, same display unit, just no symbol.

## Trimming trailing zeros

By default, `ui` zero-pads to the configured `ui_decimals`. For tokens with high precision, this produces verbose output like `"1.5000 SOL"`. Use `trim_zeros` to strip trailing zeros after rounding.

### Per call

```ruby
Amount.of_sol("2.5").ui(trim_zeros: true)   # => "2.5 SOL"
Amount.of_sol("1.0").ui(trim_zeros: true)   # => "1 SOL"
Amount.of_sol("1.0").ui(trim_zeros: false)  # => "1.0000 SOL"
```

### As a registry default

```ruby
Amount.register :SOL,
  decimals: 9,
  display_symbol: "SOL",
  display_position: :suffix,
  ui_decimals: 4,
  trim_zeros: true

Amount.of_sol("2.5").ui   # => "2.5 SOL"
Amount.of_sol("1.0").ui   # => "1 SOL"
```

Fiat currencies typically leave `trim_zeros` as `false` (the default) so that `$1.50` stays `$1.50`.

### Per display unit

Display units can override the registry default:

```ruby
Amount.register :GOLD,
  decimals: 8,
  trim_zeros: true,
  display_units: {
    gram: { scale: "31.1035", symbol: "g", ui_decimals: 2, trim_zeros: false }
  }
```

### Precedence

Call-site (`ui(trim_zeros:)`) > display unit spec > registry default.

## Locale-aware numbers

By default `ui` always uses plain digits and `.` for decimals. Pass `locale:` to
format the number with that locale's `number.format` delimiter and separator
(requires the `i18n` gem to be loaded):

```ruby
Amount.of_usd("122500").ui(locale: :en)   # => "$122,500.00"
Amount.of_usd("122500").ui(locale: :de)   # => "$122.500,00"
Amount.of_usd("122500").ui                # => "$122500.00"
```

Or opt in globally and follow `I18n.locale`:

```ruby
Amount.localize = true
Amount.of_searches(1500).ui   # => "1,500 SEARCHES" in :en
```

Missing `number.format` keys fall back to `,` and `.`. Using `locale:` or
`Amount.localize = true` without I18n raises `ArgumentError`. Rounding, `trim_zeros`
and `direction` are unchanged, and `to_s`, `formatted`, `as_json`, serialization and
`Amount.parse` never depend on the locale.

## Translated unit labels

When localizing (`locale:` or `Amount.localize = true`), labels are looked up in
I18n. Otherwise they come from `display_symbol` exactly as before.

The [Auric Vault](#auric-vault-example) bar is the best showcase: one `:GOLD`
type with three display units, each translated per locale. The registration
needs no labels at all, because the conventional keys are used:

```yaml
en:
  amounts:
    units:
      gold: "oz t"
    display_units:
      gold:
        oz_t: "oz t"
        gram: "g"
        kg: "kg"
de:
  amounts:
    units:
      gold: "Feinunze"
    display_units:
      gold:
        oz_t: "Feinunze"
        gram: "Gramm"
        kg: "Kilogramm"
```

```ruby
gold = Amount.of_gold("12.5")

gold.ui(locale: :en)                   # => "12.5000 oz t"
gold.ui(locale: :de)                   # => "12,5000 Feinunze"
gold.ui(unit: :gram, locale: :de)      # => "388,79 Gramm"
gold.ui(unit: :kg,   locale: :de)      # => "0,38879 Kilogramm"
gold.ui(unit: :gram)                   # => "388.79 g"  (not localizing)
```

The amount, its atomic value and its `to_s` (`"GOLD|12.5"`) are identical in
every locale; only the rendered label and number characters change.

To override a key, pass `label_key:` on the type or on a single display unit:

```ruby
Amount.register :SEARCHES, decimals: 0, label_key: "amounts.units.searches"
# without label_key the key is amounts.units.<symbol downcased>
```

- **Types:** `label_key`, then `amounts.units.<symbol>`, then `display_symbol`.
- **Display units:** the spec's `label_key:`, then
  `amounts.display_units.<symbol>.<unit>`, then the unit's `:symbol`, then the
  type's label.

A missing key never renders "translation missing". To get the label alone, for
column headers or chips, use `unit_label`:

```ruby
gold.unit_label(unit: :gram, locale: :de)   # => "Gramm"
gold.unit_label(unit: :kg,   locale: :de)   # => "Kilogramm"
gold.unit_label(unit: :gram)                # => "g"
Amount.of_searches(3).unit_label(locale: :de) # => "Suchen"
```

## Plural labels

Labels can agree with the number: `1 search`, `2 searches`. The count is the
number as displayed, after unit scaling and rounding (`direction:`) and before
formatting, so `1.00` is singular and `1.50` is plural.

Without I18n, give `display_symbol:` (or a display unit's `symbol:`) a hash. It
must have `:plural`; `register` rejects it otherwise.

```ruby
Amount.register :SEARCHES, decimals: 0, display_symbol: { singular: "search", plural: "searches" }

Amount.of_searches(1).ui   # => "1 search"
Amount.of_searches(0).ui   # => "0 searches"
Amount.of_searches(2).ui   # => "2 searches"
```

The hash uses `:singular` when the displayed number equals 1, else `:plural`. When
localizing with I18n loaded, the locale's pluralization rules pick the form
instead, so the hash can carry `few`, `many` and so on. Translations can be
plural hashes too:

```yaml
en:
  amounts:
    units:
      searches:
        singular: "search"
        plural: "searches"
```

`unit_label(count: 1)` follows the same rules; without a count it uses
`:plural`. String labels behave exactly as before.

## What display units are not

They are not:

- alternate storage types
- a second registry entry
- a conversion from gold to grams as a new fungible symbol

They are just scaled renderings of the same underlying amount.

## Common mistake

::: warning
`gold.ui(unit: :gram)` does not mean “this amount has become grams.” It means “show this gold amount in grams for presentation.”
:::

## See also

- [Atomic vs UI](/concepts/atomic-vs-ui)
- [Auric Vault Cookbook](/cookbook/auric-vault)
