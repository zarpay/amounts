# JavaScript Client

`@zarpay/amounts` mirrors the gem's core in JavaScript and TypeScript, for the
web and React Native. The Rails app exports its registry, and the client
parses, computes, converts, serializes and displays amounts exactly as the gem
does: on `bigint` atomic values, with no floating point and no runtime
dependencies.

## 1. Export the registry

```ruby
class AmountsManifestsController < ActionController::API
  def show
    render json: Amount.manifest(locales: I18n.available_locales)
  end
end
```

`Amount.manifest` returns a JSON-ready Hash:

- **Types**, written with the `Amount.register` option names
  (`decimals`, `display_symbol`, `display_format`, `ui_decimals`,
  `display_units`, ...).
- **Default rates**, directional, as exact decimal strings.
- **Locales**: for each one you ask for, every translation the core looks up
  (number format, labels, templates, compact words), already resolved. The
  client never needs I18n.

Serve it from an endpoint, or write it to a file at build time and import it.

## 2. Build a client

```sh
npm install @zarpay/amounts
```

```ts
import { Amounts } from "@zarpay/amounts";

const manifest = await (await fetch("/amounts/manifest")).json();
const amounts = Amounts.fromManifest(manifest);
const german = Amounts.fromManifest(manifest, { locale: "de" });
```

A malformed manifest is refused up front (`INVALID_MANIFEST`, naming the
path), so no later call fails on a missing key.

## 3. Use it

```ts
const total = amounts.of("USDC", "1.50").add(amounts.parse("USDC|0.25"));

total.ui();                   // "$1.75"
JSON.stringify({ total });    // '{"total":"USDC|1.750000"}' — what the gem's as_json writes
amounts.load(total.toHash()); // { v: 1, atomic: "1750000", symbol: "USDC" } and back

amounts.parseUi("1.500,50", "USD", { locale: "de" }); // what a person typed
amounts.of("USDC", "100").to("SOL");                  // through a registered default rate
amounts.of("USDC", "10").divide(3);                   // USDC|3.333333, truncated toward zero
amounts.of("USD", "1500000").ui({ compact: true });   // "$1.5M"
```

| Gem | Client |
| --- | --- |
| `Amount.new(v, :SYM)`, `Amount.of_sym(v)` | `amounts.of("SYM", v)` |
| `Amount.parse`, `Amount.parse_ui`, `Amount.load` | `parse`, `parseUi`, `load` |
| `+ - * /` | `add subtract multiply divide` |
| `<=> == < <= > >=` | `compare equals lessThan lessThanOrEqual greaterThan greaterThanOrEqual` |
| `to`, `split`, `allocate` | `to`, `split`, `allocate` |
| `to_h`, `as_json`, `to_s`, `formatted` | `toHash`, `toJSON`, `toString`, `formatted` |
| `ui`, `unit_label`, `display_format`, `in_unit` | `ui`, `unitLabel`, `displayFormat`, `inUnit` |

## Where JavaScript differs

- **`bigint` is atomic; `string` and `number` are whole units.** JavaScript
  can't tell `1` from `1.0`, so the gem's Integer-is-atomic rule can't carry
  over. `{ from: "atomic" }` reads a digit string or safe integer as atomic.
- **Exact decimals are strings.** `amount.decimal` is `"1.5"` and
  `inUnit("gram")` is `"31.1034768"`; scalars and rates may be decimal
  strings.
- **`Amount / Amount` is a `Ratio`**, an exact fraction
  (`ratio.toFixed(4)`), not a rounded `BigDecimal`.
- **Errors are one class**, `AmountError`, with a `code` per gem exception
  (`TYPE_MISMATCH`, `NO_DEFAULT_RATE`, ...).
- **Plural forms follow I18n's default rule** (`zero`, `one`, `other`).

The full design is in the client's
[`specs/`](https://github.com/zarpay/amounts/tree/main/client/specs).
