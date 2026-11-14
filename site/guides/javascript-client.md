# JavaScript Client

`@zarpay/amounts` brings the gem to the frontend: the web, Node and React
Native. The Rails app exports its registry once; the client reads it and
then parses, computes, converts, serializes and displays amounts exactly as
the gem does: same atomic integers, same rounding, same strings.

```ts
const total = amounts.of("USDC", "19.99").multiply(3);

total.ui();       // "$59.97"
total.toJSON();   // "USDC|59.970000"  ← what a Rails model with has_amount reads
```

## Why not just use numbers?

Because a JavaScript `number` is a binary float, and money isn't:

```js
0.1 + 0.2                   // 0.30000000000000004
9.95 * 3                    // 29.849999999999998
Math.round(4.35 * 100)      // 435, but 4.35 * 100 is 434.99999999999994 — Math.floor gives 434
1e18 + 1 === 1e18           // true — one wei is lost on a single ETH
```

Every app that does money math with `number` ends up with rounding helpers,
`toFixed` calls in odd places, and totals that disagree with the server by a
cent. The client stores every amount as a `bigint` count of the type's
smallest unit and computes with exact fractions, so `9.95 * 3` is `29.85`
and an ETH balance keeps every wei:

```ts
amounts.of("USD", "9.95").multiply(3).ui();     // "$29.85"
amounts.of("ETH", 10n ** 18n + 1n).atomic;      // 1000000000000000001n
```

And because the client is built from the server's own registry, the
frontend can't disagree with the backend about how many decimals USDC has,
what a rate is, or how a label is spelled.

## How it works

```
config/initializers/amounts.rb       Amount.register :USDC, ...
            │
            ▼
Amount.manifest(locales: [...])      types, default rates, translations → JSON
            │
            ▼  GET /amounts/manifest, or a JSON file in your bundle
Amounts.fromManifest(manifest)       a client that mirrors the gem's core
            │
            ▼
amounts.of("USDC", "1.50") …         exact math and display in the browser
```

The client never registers anything itself. To add a type or change a rate,
change the initializer; the next manifest the client loads has it.

The examples on this page use this registry:

```ruby
# config/initializers/amounts.rb
Amount.register :USDC, decimals: 6, display_symbol: "$", display_position: :prefix, ui_decimals: 2
Amount.register :USD,  decimals: 2, display_symbol: "$", display_position: :prefix
Amount.register :EUR,  decimals: 2, display_symbol: "€", display_format: "%u%n"
Amount.register :SOL,  decimals: 9, display_symbol: "SOL", ui_decimals: 4, trim_zeros: true
Amount.register :ETH,  decimals: 18, display_symbol: "ETH", ui_decimals: 4
Amount.register :GOLD, decimals: 8, display_symbol: "oz t", ui_decimals: 4,
                       display_units: { gram: { scale: "31.1034768", symbol: "g", ui_decimals: 2 } }
Amount.register :SEARCHES, decimals: 0, display_symbol: { one: "search", other: "searches" }

Amount.register_default_rate :USD,  :USDC, "1"
Amount.register_default_rate :USDC, :USD,  "1"
Amount.register_default_rate :USDC, :SOL,  "0.0066666666"
```

## Install

```sh
npm install @zarpay/amounts
```

The package has no runtime dependencies. It ships ESM and CommonJS builds
with TypeScript declarations, and needs only `bigint`: every current
browser, Node 18+, and React Native 0.70+ on Hermes.

## 1. Export the registry

`Amount.manifest` returns the registry as a JSON-ready Hash. Pass the
locales your frontend displays in, and the gem resolves every translation
the core looks up for them:

```ruby
Amount.manifest                                 # types and rates
Amount.manifest(locales: %i[en de])             # plus the en and de tables (needs I18n)
Amount.manifest(locales: I18n.available_locales)
```

### Serve it from an endpoint

The usual setup: the frontend fetches it once at startup.

```ruby
# config/routes.rb
get "amounts/manifest" => "amounts_manifests#show"

# app/controllers/amounts_manifests_controller.rb
class AmountsManifestsController < ActionController::API
  def show
    # The registry only changes on deploy, so let browsers and CDNs cache it.
    expires_in 1.hour, public: true
    render json: Amount.manifest(locales: I18n.available_locales)
  end
end
```

### Or bundle it at build time

When the frontend is built separately, or you want the client ready without
a request, write the manifest to a file and import it:

```ruby
# lib/tasks/amounts.rake
namespace :amounts do
  desc "Write the amounts manifest for the frontend"
  task manifest: :environment do
    path = Rails.root.join("app/javascript/amounts.json")
    File.write(path, JSON.pretty_generate(Amount.manifest(locales: I18n.available_locales)))
  end
end
```

Run `bin/rails amounts:manifest` as part of your frontend build, so a
registry change can't ship without its manifest.

### What's in it

```json
{
  "v": 1,
  "types": {
    "USDC": {
      "decimals": 6, "display_symbol": "$", "display_format": "%u%n",
      "ui_decimals": 2, "trim_zeros": false, "display_units": null, "default_display": null
    }
  },
  "rates": [{ "from": "USDC", "to": "SOL", "rate": "0.0066666666" }],
  "locales": {
    "de": {
      "number": { "delimiter": ".", "separator": "," },
      "compact": { "format": "%n %u", "units": { "million": { "one": "Million", "other": "Millionen" } } },
      "types": { "USDC": { "label": null, "format": "%n %u", "units": {} } }
    }
  }
}
```

Keys are the `Amount.register` option names. Rates are exact decimal
strings. Locale tables hold the translations themselves, so the client
needs neither I18n nor your locale files. The full format is in the
client's [manifest spec](https://github.com/zarpay/amounts/blob/main/client/specs/02-manifest.md).

## 2. Create a client

```ts
import { Amounts } from "@zarpay/amounts";

const manifest = await (await fetch("/amounts/manifest")).json();
export const amounts = Amounts.fromManifest(manifest);
```

Create one client and share it. It's immutable, so a module-level export is
fine. `fromManifest` validates the whole manifest up front: a malformed one
throws `INVALID_MANIFEST` naming the bad path (`types.USDC.decimals`), and a
client that constructs never fails later on a missing key.

### A default locale

Pass `locale` to make every call follow a locale when it doesn't name one,
like the gem's `Amount.localize = true` with `I18n.locale`:

```ts
const amounts = Amounts.fromManifest(manifest, { locale: "de" });

amounts.of("USD", "1500.5").ui();                  // "$1.500,50"
amounts.of("USD", "1500.5").ui({ locale: "en" });  // "$1,500.50" — a call can still override it
```

The locale must be one the manifest was exported with; anything else throws
`UNKNOWN_LOCALE`.

### In React

Load the manifest once and provide the client through context:

```tsx
import { createContext, useContext, useEffect, useState } from "react";
import { Amounts } from "@zarpay/amounts";

const AmountsContext = createContext<Amounts | null>(null);

export function AmountsProvider({ locale, children }: { locale: string; children: React.ReactNode }) {
  const [amounts, setAmounts] = useState<Amounts | null>(null);

  useEffect(() => {
    fetch("/amounts/manifest")
      .then((response) => response.json())
      .then((manifest) => setAmounts(Amounts.fromManifest(manifest, { locale })));
  }, [locale]);

  if (amounts === null) return null;

  return <AmountsContext.Provider value={amounts}>{children}</AmountsContext.Provider>;
}

export function useAmounts(): Amounts {
  const amounts = useContext(AmountsContext);
  if (amounts === null) throw new Error("useAmounts needs an <AmountsProvider>");
  return amounts;
}
```

With a bundled manifest there's nothing to load:
`Amounts.fromManifest(manifest, { locale })` can run directly in a `useMemo`.

### In React Native

Nothing changes: the package uses no Node or browser APIs and no `Intl`.
Import the bundled JSON, or fetch the manifest from your API on launch and
keep it in storage for offline starts:

```ts
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Amounts } from "@zarpay/amounts";
import bundled from "./amounts.json";

export async function loadAmounts(): Promise<Amounts> {
  try {
    const manifest = await (await fetch(`${API_URL}/amounts/manifest`)).json();
    await AsyncStorage.setItem("amounts-manifest", JSON.stringify(manifest));
    return Amounts.fromManifest(manifest);
  } catch {
    const cached = await AsyncStorage.getItem("amounts-manifest");
    return Amounts.fromManifest(cached ? JSON.parse(cached) : bundled);
  }
}
```

## 3. Construct amounts

`amounts.of` is the gem's `Amount.new` (and its `Amount.of_usdc`
constructors). How it reads a value depends on the value's JavaScript type:

| Input | Read as | Example | Value |
| --- | --- | --- | --- |
| `bigint` | atomic units | `amounts.of("USDC", 1_500_000n)` | 1.50 |
| `string` | whole units, exactly | `amounts.of("USDC", "1.50")` | 1.50 |
| `number` | whole units, through its string form | `amounts.of("USDC", 1.5)` | 1.50 |

Ruby reads an `Integer` as atomic and a `Float` as whole units, but
JavaScript can't tell `1` from `1.0`, so the client splits on type instead.
`bigint` is the only atomic input, which keeps a large atomic value from
silently losing digits as a `number`. Use `from` when the type doesn't say
what you mean:

```ts
amounts.of("USDC", "1500000", { from: "atomic" });  // atomic units from a string: 1.50
amounts.of("USDC", 2n, { from: "ui" });             // whole units from a bigint: 2.00
amounts.of("ETH", 10n ** 18n);                      // one ETH, every wei exact
```

A string is read exactly in Ruby's `BigDecimal` grammar (`"1_000"`, `"1e3"`,
`".5"`), and a `number` goes through its string form, so `0.1` is exactly
one tenth. Extra decimal places are truncated toward zero, as the gem
truncates them: `amounts.of("USDC", "1.1234567")` is `1.123456`. When the
value comes from a person, use [`parseUi`](#forms-and-user-input) instead,
which refuses extra places rather than dropping them.

## 4. Talk to your API

### Reading amounts

A Rails model with `has_amount` writes each amount as its exact compact
string, and `parse` reads it back:

```ts
// GET /wallets/1  →  { "id": 1, "balance": "USDC|1042.500000" }
const wallet = await (await fetch("/wallets/1")).json();
const balance = amounts.parse(wallet.balance);

balance.ui();  // "$1042.50"
```

`parse` accepts the versioned form too (`"v1:USDC|1.50"`). For the hash
payload the gem's `to_h` writes, use `load`:

```ts
amounts.load({ v: 1, atomic: "1500000", symbol: "USDC" }).ui();  // "$1.50"
```

When a response has several amounts, map the keys you know at the edge, so
the rest of the app only ever sees `Amount`s:

```ts
type Invoice = { id: number; subtotal: Amount; tax: Amount; total: Amount };

function readInvoice(json: Record<string, unknown>): Invoice {
  return {
    id: json.id as number,
    subtotal: amounts.parse(json.subtotal as string),
    tax: amounts.parse(json.tax as string),
    total: amounts.parse(json.total as string),
  };
}
```

### Sending amounts

An amount's `toJSON` writes the same compact string, so `JSON.stringify`
does the right thing, and a `has_amount` writer on the server reads it
directly:

```ts
const transfer = { recipient_id: 7, amount: amounts.of("USDC", "25") };

await fetch("/transfers", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(transfer),   // {"recipient_id":7,"amount":"USDC|25.000000"}
});
```

```ruby
# app/controllers/transfers_controller.rb
Transfer.create!(params.permit(:recipient_id, :amount))  # has_amount :amount casts "USDC|25.000000"
```

The compact string never rounds, so an amount survives any number of round
trips unchanged. `toString()` (`"USDC|25.00"`) is display-rounded, for logs
only.

## 5. Forms and user input

`parseUi` reads what a person typed, in a locale's number format. It's the
gem's `Amount.parse_ui`:

```ts
amounts.parseUi("1,500.50", "USD", { locale: "en" });  // USD 1500.50
amounts.parseUi("1.500,50", "USD", { locale: "de" });  // USD 1500.50
amounts.parseUi("$12.50", "USD");                       // a label at either end is fine
amounts.parseUi("-12.5", "USD");                        // so is a sign
```

It accepts surrounding whitespace, a leading `-` or `+`, delimiters in
groups of three, and the type's label at either end (any plural form, or
its translation). It never rounds: more decimal places than the type
stores is an error, so nobody submits a value they didn't type.

```ts
amounts.parseUi("1.234", "USD");     // INVALID_INPUT: has more than 2 decimal places
amounts.parseUi("1,500.50", "USD");  // INVALID_INPUT: is not a number (no locale, so no delimiters)
amounts.parseUi("", "USD");          // INVALID_INPUT: is empty
```

### A validated input

```tsx
import { AmountError, type Amount } from "@zarpay/amounts";

function AmountField({ symbol, onChange }: { symbol: string; onChange: (amount: Amount | null) => void }) {
  const amounts = useAmounts();
  const [error, setError] = useState<string | null>(null);
  const { decimals } = amounts.registry.lookup(symbol);

  function handleChange(text: string) {
    try {
      onChange(amounts.parseUi(text, symbol));
      setError(null);
    } catch (caught) {
      if (!(caught instanceof AmountError) || caught.code !== "INVALID_INPUT") throw caught;
      onChange(null);
      setError(text.trim() === "" ? null : `Enter an amount with up to ${decimals} decimals`);
    }
  }

  return (
    <label>
      <input inputMode="decimal" onChange={(event) => handleChange(event.target.value)} />
      <span>{amounts.of(symbol, 0n).unitLabel()}</span>
      {error && <p role="alert">{error}</p>}
    </label>
  );
}
```

To prefill an input from an amount, use `ui({ decorated: false })` for a
localized number without the label, or `decimal` for a plain one:

```ts
balance.ui({ decorated: false, locale: "de" });  // "1.042,50"
balance.decimal;                                  // "1042.5"
```

## 6. Math

Every operation returns a new amount; amounts are frozen and never change.
JavaScript has no operator overloading, so the operators are methods:

```ts
const price = amounts.of("USDC", "19.99");

price.add(amounts.of("USDC", "5"));       // 24.99
price.subtract(amounts.of("USDC", "5"));  // 14.99
price.multiply(3);                        // 59.97
price.multiply("0.075");                  // 1.499250 — a 7.5% fee, exact
price.divide(4);                          // 4.9975 — truncated toward zero to the atomic unit
price.negate();                           // -19.99
price.abs();                              // 19.99
```

Scalars are read exactly: pass a decimal string (`"0.075"`), a `number`
(read through its string form) or a `bigint`. Multiplying and dividing
compute the exact result and then truncate toward zero to the atomic unit,
as the gem does.

### Sums

Start from a zero of the type and add:

```ts
const zero = amounts.of("USD", 0n);
const total = lineItems.reduce((sum, item) => sum.add(item.price), zero);
```

### Comparing and sorting

```ts
cost.greaterThan(balance);     // also lessThan, lessThanOrEqual, greaterThanOrEqual
cost.equals(other);            // same type and value
cost.compare(other);           // -1, 0, 1, or null when they can't be compared
cost.isZero();                 // also isPositive, isNegative

const sorted = [...balances].sort((a, b) => a.compare(b) ?? 0);
```

`equals` never converts: one USDC doesn't equal one USD, whatever the rate.
`compare`, `lessThan` and the rest compare values, converting through a
default rate when one exists.

### Across types

Mixing types only works through a default rate the server registered.
With USD → USDC registered at 1:

```ts
amounts.of("USDC", "10").add(amounts.of("USD", "5"));   // USDC 15.00 — in the receiver's type
amounts.of("USDC", "1").add(amounts.of("GOLD", "1"));   // TYPE_MISMATCH: no USDC ← GOLD rate
```

There's no implicit conversion and no inverted rate. That's the same rule
the gem enforces, so the frontend can't compute a total the backend would
refuse.

### Ratios

Dividing an amount by another of the same type gives their exact ratio, a
`Ratio`, which is never rounded:

```ts
const share = amounts.of("USDC", "25").divide(amounts.of("USDC", "200"));

share.toString();     // "1/8"
share.toFixed(4);     // "0.1250"
share.numerator;      // 1n
share.denominator;    // 8n
```

## 7. Conversion

`to` converts with the registered default rate, or with a rate you pass:

```ts
amounts.of("USDC", "100").to("SOL").ui();                    // "0.6666 SOL" (rate 0.0066666666)
amounts.of("USDC", "100").to("GOLD", { rate: quote.rate });  // a live quote
amounts.of("USDC", "100").to("GOLD");                        // NO_DEFAULT_RATE
```

The value is multiplied by the rate and truncated toward zero to the
target's atomic unit. Rates are directional: a USDC → SOL rate doesn't
convert SOL → USDC.

Ask the registry what's possible before offering it:

```ts
const { registry } = amounts;
const targets = registry.symbols.filter((symbol) => registry.hasDefaultRate("USDC", symbol));
```

## 8. Splitting and allocation

Dividing money never loses any. `split` and `allocate` return the parts and
the leftover separately, and the parts plus the remainder always add back up
to the original:

```ts
const [parts, remainder] = amounts.of("USD", "100").split(3);

parts.map((part) => part.ui());   // ["$33.33", "$33.33", "$33.33"]
remainder.ui();                   // "$0.01"
```

Decide what happens to the remainder. For example, give it to the first
person:

```ts
const shares = parts.map((part, index) => (index === 0 ? part.add(remainder) : part));
// ["$33.34", "$33.33", "$33.33"]
```

`allocate` splits by integer weights:

```ts
const [[creator, platform, referrer], rest] = amounts.of("USDC", "99.99").allocate([70, 20, 10]);
```

## 9. Display

`ui` turns an amount into text for people. It's the gem's `ui`, with the
same options:

```ts
const amount = amounts.of("USD", "1500.5");

amount.ui();                              // "$1500.50"     plain: no locale, no delimiters
amount.ui({ locale: "en" });              // "$1,500.50"
amount.ui({ locale: "de" });              // "$1.500,50"
amount.ui({ decorated: false });          // "1500.50"      the number alone
amount.ui({ compact: true });             // "$1.5K"
amounts.of("USDC", "1.231").ui({ direction: "ceil" });  // "$1.24"
```

| Option | Default | Does |
| --- | --- | --- |
| `locale` | the client's | the locale's delimiter, separator, labels and templates |
| `direction` | `"floor"` | round down, or `"ceil"` to round up |
| `decorated` | `true` | `false` returns the number without the label |
| `trimZeros` | the type's | strip trailing zeros after rounding |
| `unit` | — | show in one of the type's display units |
| `compact` | `false` | `true` or `{ precision }` for `1.5M` notation |

Rounding goes down by default, so a balance never shows as more than it is.
The digits are written from the exact value, so an 18-decimal token shows
every digit correctly.

### Locales and templates

A locale brings its number format, and can bring its own labels and
templates. With German translations that put the euro sign after the
number:

```ts
const eur = amounts.of("EUR", "12.5");

eur.ui();                   // "€12.50"
eur.ui({ locale: "de" });   // "12,50 €"  (from amounts.formats.eur, with a non-breaking space)
```

### Plural labels

A type registered with plural labels agrees with the number shown:

```ts
amounts.of("SEARCHES", 1n).ui();                  // "1 search"
amounts.of("SEARCHES", 3n).ui();                  // "3 searches"
amounts.of("SEARCHES", 3n).ui({ locale: "de" });  // "3 Suchen", from amounts.units.searches
```

In a locale, forms are picked by I18n's default rule: `zero` when the count
is 0 and that form exists, `one` for 1, else `other`.

### Display units

Display units change how an amount is shown, never what it is:

```ts
const gold = amounts.of("GOLD", "1");

gold.ui();                    // "1.0000 oz t"
gold.ui({ unit: "gram" });    // "31.10 g"
gold.inUnit("gram");          // "31.1034768" — exact
```

### Compact notation

For dashboards and cards:

```ts
amounts.of("USD", "1500000").ui({ compact: true });                // "$1.5M"
amounts.of("USD", "1999999").ui({ compact: true });                // "$1.99M" — never rounds up by default
amounts.of("USD", "1234567").ui({ compact: { precision: 2 } });    // "$1.2M"
amounts.of("USD", "2500000").ui({ compact: true, locale: "de" });  // "$2,5 Millionen"
```

### Laying out the label yourself

When the label goes somewhere else (a column header, a chip, a styled
span), take the parts separately:

```tsx
function Money({ amount }: { amount: Amount }) {
  const number = amount.ui({ decorated: false });
  const label = <small className="unit">{amount.unitLabel({ count: amount.decimal })}</small>;
  const format = amount.displayFormat();
  const labelFirst = format.indexOf("%u") < format.indexOf("%n");

  return (
    <span className="money">
      {labelFirst && label}
      {number}
      {!labelFirst && label}
    </span>
  );
}
```

`displayFormat()` returns the template, such as `"%u%n"` for `$1.50` or
`"%n %u"` for `2.5 SOL`, so the label lands on the correct side for each
type and locale.

## 10. Errors

Everything the client throws is an `AmountError` with a `code`. Branch on
the code, not the message:

| Code | When |
| --- | --- |
| `INVALID_INPUT` | a value, compact string, typed input or payload can't be read |
| `TYPE_MISMATCH` | mixing types without a default rate; a non-scalar operand |
| `UNKNOWN_TYPE` | a symbol the manifest doesn't register |
| `NO_DEFAULT_RATE` | `to` without a rate, and none registered |
| `INVALID_DISPLAY_UNIT` | a display unit the type doesn't have |
| `ZERO_DIVISION` | dividing by zero |
| `NOT_COMPARABLE` | `lessThan` and friends across types without a rate |
| `INVALID_ARGUMENT` | bad `split`, `allocate` or `compact` arguments |
| `UNKNOWN_LOCALE` | a locale the manifest wasn't exported with |
| `INVALID_MANIFEST` | `fromManifest` on a malformed manifest |

```ts
import { AmountError } from "@zarpay/amounts";

try {
  converted = balance.to(target);
} catch (error) {
  if (error instanceof AmountError && error.code === "NO_DEFAULT_RATE") {
    converted = null;   // offer a quote instead
  } else {
    throw error;
  }
}
```

## Gem and client side by side

| Gem | Client |
| --- | --- |
| `Amount.new(v, :SYM)`, `Amount.of_sym(v)` | `amounts.of("SYM", v)` |
| `Amount.parse`, `Amount.parse_ui`, `Amount.load` | `amounts.parse`, `amounts.parseUi`, `amounts.load` |
| `Amount.registry` | `amounts.registry` |
| `Amount.localize = true` + `I18n.locale` | `Amounts.fromManifest(m, { locale })` |
| `+` `-` `*` `/` | `add` `subtract` `multiply` `divide` |
| `-amount`, `abs` | `negate()`, `abs()` |
| `<=>` `==` `<` `<=` `>` `>=` | `compare` `equals` `lessThan` `lessThanOrEqual` `greaterThan` `greaterThanOrEqual` |
| `zero?` `positive?` `negative?` `same_type?` | `isZero` `isPositive` `isNegative` `sameType` |
| `to(:SYM, rate:)` | `to("SYM", { rate })` |
| `split(n)`, `allocate(weights)` | `split(n)`, `allocate(weights)` |
| `atomic`, `symbol`, `decimals`, `decimal` | `atomic` (`bigint`), `symbol`, `decimals`, `decimal` (string) |
| `to_h`, `as_json`, `to_s`, `formatted` | `toHash()`, `toJSON()`, `toString()`, `formatted()` |
| `ui(...)`, `unit_label`, `display_format`, `in_unit` | `ui({...})`, `unitLabel`, `displayFormat`, `inUnit` |

### Where JavaScript differs

- **`bigint` is atomic; `string` and `number` are whole units.** JavaScript
  can't tell `1` from `1.0`.
- **Exact decimals are strings.** `decimal` is `"1.5"` and
  `inUnit("gram")` is `"31.1034768"`, where Ruby returns a `BigDecimal`. A
  scalar or rate may be a decimal string, the client's stand-in for
  `BigDecimal`.
- **`Amount / Amount` is a `Ratio`**, an exact fraction, where Ruby returns
  a rounded `BigDecimal`.
- **Errors are one class with a code**, instead of Ruby's exception classes.
- **Very large numbers display correctly.** The gem's `ui` goes through a
  Float and prints wrong digits past about 15 significant figures; the
  client writes the exact digits.

## Keeping the two in step

The client mirrors the gem release for release. Its test suite runs against
a manifest the gem exported, and every expected value in it is the gem's
own output for that registry. CI exports that manifest again on every
commit and fails if it changed without the client following.

The manifest is versioned (`"v": 1`). A gem that changes its shape bumps
the version, and an older client refuses the new manifest with
`INVALID_MANIFEST` rather than misreading it. Upgrade the gem and the
client together.

The design notes are in the client's
[`specs/`](https://github.com/zarpay/amounts/tree/main/client/specs): what's
mirrored, the manifest format and the full interface.
