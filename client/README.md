# @zarpay/amounts

Exact amounts of money, tokens and commodities in JavaScript and TypeScript,
for the web and React Native. It mirrors the [`amounts`](../gem) gem: the
Rails app exports its registry, and the client parses, computes, converts,
serializes and displays amounts exactly as the gem does, on `bigint` atomic
values, with no runtime dependencies.

## Install

```sh
npm install @zarpay/amounts
```

ESM and CommonJS builds ship with TypeScript declarations. It needs `bigint`
(every current browser, Node 18+, React Native 0.70+ on Hermes).

**Versions match the gem.** `@zarpay/amounts` 0.3.0 mirrors `amounts` 0.3.0,
and both are released together. Use the same version on both sides: the
manifest a newer gem writes may not be one an older client reads.

## Export the registry from Rails

```ruby
class AmountsManifestsController < ActionController::API
  def show
    render json: Amount.manifest(locales: I18n.available_locales)
  end
end
```

`Amount.manifest` writes the registered types, the default rates and, for each
locale, every translation the gem looks up. The client never needs I18n.
Serve it from an endpoint, or write it to a file at build time and import it.

## Use it

```ts
import { Amounts, AmountError } from "@zarpay/amounts";
import manifest from "./amounts.json";

const amounts = Amounts.fromManifest(manifest);

const total = amounts.of("USDC", "1.50").add(amounts.parse("USDC|0.25"));
total.ui();                     // "$1.75"
JSON.stringify({ total });      // '{"total":"USDC|1.750000"}'
amounts.load(total.toHash());   // back from { v: 1, atomic: "1750000", symbol: "USDC" }
```

### Constructing

```ts
amounts.of("USDC", 1_500_000n);                     // bigint: atomic units
amounts.of("USDC", "1.50");                         // string: whole units
amounts.of("USDC", 1.5);                            // number: whole units, through "1.5"
amounts.of("USDC", "1500000", { from: "atomic" });  // override the inference
amounts.parse("USDC|1.50");                         // the compact string toJSON writes
amounts.parseUi("1.500,50 $", "USD", { locale: "de" }); // what a person typed
```

JavaScript can't tell `1` from `1.0`, so the gem's Integer-is-atomic rule
becomes **`bigint` is atomic**.

### Math, comparison and conversion

```ts
a.add(b); a.subtract(b);            // same type, or through a registered default rate
a.multiply("0.3333333");            // exact, then truncated toward zero
a.divide(3);                        // exact, then truncated toward zero
a.divide(b);                        // a Ratio: exact fraction, b.toFixed(4) → "3.3333"
a.abs(); a.negate();
a.compare(b);                       // -1 | 0 | 1 | null
a.equals(b);                        // same type and value, never converts
a.lessThan(b);                      // also lessThanOrEqual, greaterThan, greaterThanOrEqual
a.to("SOL");                        // through the default rate
a.to("GOLD", { rate: "0.00042" });  // through an explicit one
const [parts, remainder] = a.split(3);   // parts + remainder always equal a
a.allocate([1, 1, 2]);
```

Scalars and rates take a `bigint`, a `number` or a decimal `string`. No
value ever goes through floating point.

### Display

```ts
amount.ui();                                  // "$1.50"
amount.ui({ locale: "de" });                  // "$1.500,50", or the locale's template if it has one
amount.ui({ direction: "ceil" });             // round away from zero instead of toward it
amount.ui({ decorated: false });              // the number alone
amount.ui({ trimZeros: true });
amount.ui({ unit: "gram" });                  // a display unit: "31.10 g"
amount.ui({ compact: true });                 // "$1.5M"
amount.unitLabel({ count: 1 });               // "search"
amount.displayFormat();                       // "%u%n"
amount.inUnit("gram");                        // "31.1034768", exact
amount.decimal;                               // "1.5", exact
amount.formatted();                           // "1.500000"
amount.toString();                            // "USDC|1.50"
```

`Amounts.fromManifest(manifest, { locale: "de" })` makes every call follow a
locale when it doesn't name one, like the gem's `Amount.localize = true`.

### Errors

Every error is an `AmountError` with a `code`: `TYPE_MISMATCH`,
`INVALID_INPUT`, `UNKNOWN_TYPE`, `NO_DEFAULT_RATE`, `INVALID_DISPLAY_UNIT`,
`ZERO_DIVISION`, `INVALID_ARGUMENT`, `NOT_COMPARABLE`, `UNKNOWN_LOCALE` or
`INVALID_MANIFEST`. Branch on the code, not the message.

## Parity with the gem

The design is in [`specs/`](./specs): what is mirrored, the manifest format,
and the interface. The tests run against a manifest the gem exported from
[`tests/fixtures/registry.rb`](./tests/fixtures/registry.rb), and their
expected values are the gem's output for it. CI exports that manifest again
from each commit's gem and fails if it differs from the committed fixture.

The client formats from the exact value. Past about 15 significant digits the
gem's `ui` goes through a Float and prints wrong digits; the client prints the
right ones.

## Development

```sh
npm install
npm test             # vitest
npm run lint         # eslint
npm run typecheck    # tsc --noEmit
npm run format       # prettier
npm run build        # tsup: dist/ (ESM, CJS, .d.ts)
```

After changing the gem's export, regenerate the fixture from `gem/`:

```sh
bundle exec ruby -Ilib ../client/tests/fixtures/export-manifest.rb
```
