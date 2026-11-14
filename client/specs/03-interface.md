# 03 — Interface

The public API, as TypeScript. Plain JavaScript callers use the same names.
Every name maps to a gem method ([01](./01-surface.md#in-scope--the-gems-core-mirrored)).

## Constructing a client

```ts
import { Amounts } from "@zarpay/amounts";
import manifest from "./amounts.json";

const amounts = Amounts.fromManifest(manifest);
const german = Amounts.fromManifest(manifest, { locale: "de" });
```

```ts
class Amounts {
  /** @throws AmountError INVALID_MANIFEST, UNKNOWN_LOCALE */
  static fromManifest(manifest: unknown, options?: AmountsOptions): Amounts;

  readonly registry: Registry;
  /** The locale `ui`, `unitLabel`, `displayFormat` and `parseUi` use when none is given. */
  readonly locale: string | null;

  /** `Amount.new` / `Amount.of_usdc`. @throws UNKNOWN_TYPE, INVALID_INPUT */
  of(symbol: string, value: AmountInput, options?: { from?: "atomic" | "ui" }): Amount;
  /** `Amount.parse`: `"USDC|1.50"` or `"v1:USDC|1.50"`. @throws INVALID_INPUT, UNKNOWN_TYPE */
  parse(compact: string): Amount;
  /** `Amount.parse_ui`: what a person typed. @throws INVALID_INPUT, UNKNOWN_TYPE, UNKNOWN_LOCALE */
  parseUi(input: string, symbol: string, options?: { locale?: string }): Amount;
  /** `Amount.load`: the `toHash()` payload. @throws INVALID_INPUT, UNKNOWN_TYPE */
  load(payload: AmountHash): Amount;
  /** The locale table a call uses: the given one, else the client's, else null. */
  localeFor(explicit: string | null | undefined): Locale | null;
}

type AmountsOptions = { locale?: string | null };
type AmountInput = bigint | number | string;
type DecimalInput = bigint | number | string;
type AmountHash = { v?: number | null; atomic: bigint | number | string; symbol: string };
```

Value inference, as in [01 §2](./01-surface.md#decisions-that-differ-from-ruby-and-why):

```ts
amounts.of("USDC", 1_500_000n);                   // atomic: 1.50
amounts.of("USDC", "1.50");                       // UI: 1.50
amounts.of("USDC", 1.5);                          // UI, through "1.5": 1.50
amounts.of("USDC", "1500000", { from: "atomic" }); // atomic: 1.50
```

## The registry

```ts
class Registry {
  readonly symbols: string[];
  registered(symbol: string): boolean;
  /** @throws UNKNOWN_TYPE */
  lookup(symbol: string): RegistryEntry;
  /** The rate as an exact decimal string. @throws NO_DEFAULT_RATE */
  defaultRate(from: string, to: string): string;
  hasDefaultRate(from: string, to: string): boolean;
}

class RegistryEntry {
  readonly symbol: string;
  readonly decimals: number;
  readonly displaySymbol: Label;
  readonly displayFormat: string;
  readonly uiDecimals: number;
  readonly trimZeros: boolean;
  readonly displayUnits: Record<string, DisplayUnit> | null;
  readonly defaultDisplay: string | null;
  /** @throws INVALID_DISPLAY_UNIT */
  displayUnit(unit: string): DisplayUnit;
}

type Label = string | { zero?: string; one?: string; other: string };
type DisplayUnit = {
  scale: string;
  symbol: Label | null;
  uiDecimals: number | null;
  format: string | null;
  trimZeros: boolean | null;
};
```

## Amount

```ts
class Amount {
  readonly atomic: bigint;
  readonly symbol: string;
  readonly decimals: number;
  readonly registryEntry: RegistryEntry;
  /** The exact value in whole units, as `BigDecimal#to_s("F")` writes it: "1.5", "1.0". */
  readonly decimal: string;

  // Calculable
  add(other: Amount): Amount;               // TYPE_MISMATCH without a default rate
  subtract(other: Amount): Amount;
  multiply(scalar: DecimalInput): Amount;   // truncates toward zero
  divide(scalar: DecimalInput): Amount;     // exact, then truncates toward zero; ZERO_DIVISION
  divide(other: Amount): Ratio;             // same type only; ZERO_DIVISION
  abs(): Amount;
  negate(): Amount;

  // Orderable
  sameType(other: unknown): boolean;
  compare(other: unknown): -1 | 0 | 1 | null; // null when not comparable (`<=>`)
  equals(other: unknown): boolean;            // same type and atomic value, no conversion (`==`)
  lessThan(other: Amount): boolean;           // NOT_COMPARABLE when compare is null
  lessThanOrEqual(other: Amount): boolean;
  greaterThan(other: Amount): boolean;
  greaterThanOrEqual(other: Amount): boolean;
  isZero(): boolean;
  isPositive(): boolean;
  isNegative(): boolean;

  // Convertible
  to(symbol: string, options?: { rate?: DecimalInput }): Amount; // NO_DEFAULT_RATE, UNKNOWN_TYPE

  // Allocatable — the parts plus the remainder always sum to the receiver
  split(n: number): [Amount[], Amount];
  allocate(weights: (number | bigint)[]): [Amount[], Amount];

  // Serializable
  toHash(): { v: 1; atomic: string; symbol: string };
  toJSON(): string;   // "USDC|1.500000" — exact; JSON.stringify uses it
  toString(): string; // "USDC|1.50" — display-rounded, as the gem's `to_s`
  formatted(): string; // "1.500000" — exactly `decimals` places

  // Display
  ui(options?: UiOptions): string;
  unitLabel(options?: { unit?: string; locale?: string; count?: DecimalInput }): string;
  displayFormat(options?: { unit?: string; locale?: string }): string;
  inUnit(unit: string): string; // exact decimal string
}

type UiOptions = {
  unit?: string;
  direction?: "floor" | "ceil";
  decorated?: boolean;
  trimZeros?: boolean | null;
  locale?: string;
  compact?: boolean | { precision?: number };
};
```

## Ratio

The exact result of `Amount#divide(Amount)`.

```ts
class Ratio {
  readonly numerator: bigint;   // carries the sign
  readonly denominator: bigint; // always positive; the fraction is reduced
  /** Rounded to `places` decimals in `direction`, as `ui` rounds. */
  toFixed(places: number, direction?: "floor" | "ceil"): string;
  toString(): string; // "10/3"
}
```

## Errors

One class, `AmountError extends Error`, with a `code`:

| Code                   | Gem                                         | Raised by                                   |
| ---------------------- | ------------------------------------------- | ------------------------------------------- |
| `TYPE_MISMATCH`        | `Amount::TypeMismatch`                      | cross-type math without a rate; a non-scalar |
| `INVALID_INPUT`        | `Amount::InvalidInput`                      | unparseable values and payloads             |
| `UNKNOWN_TYPE`         | `Registry::UnknownType`                     | an unregistered symbol                      |
| `NO_DEFAULT_RATE`      | `Registry::NoDefaultRate`                   | `to` without a rate                         |
| `INVALID_DISPLAY_UNIT` | `Registry::InvalidDisplayUnit`              | an unknown display unit                     |
| `ZERO_DIVISION`        | `ZeroDivisionError`                         | dividing by zero                            |
| `INVALID_ARGUMENT`     | `ArgumentError`                             | bad `split`/`allocate`/`compact` arguments  |
| `NOT_COMPARABLE`       | `ArgumentError` from `Comparable`           | `lessThan` etc. across unrelated types      |
| `UNKNOWN_LOCALE`       | — (I18n would raise `InvalidLocale`)        | a locale the manifest has no table for      |
| `INVALID_MANIFEST`     | —                                           | `fromManifest` on a malformed manifest      |

## Source layout

The files mirror the gem's, so a change to one side has an obvious
counterpart on the other. Ruby's concerns are mixins; here they are the
sections of `Amount`.

```
src/
  index.ts                 the public exports
  types.ts                 barrel over src/types/ — the manifest and option shapes
  helpers/
    errors-helper.ts       AmountError and one factory per code
    decimal-helper.ts      exact decimal strings in and out (BigDecimal's grammar)
    template-helper.ts     Formattable's template primitives
  models/
    amounts.ts             the client: Amount's class methods (of, parse, parseUi, load)
    registry.ts            Registry, from the manifest
    registry-entry.ts      Registry::Entry
    locale.ts              one locale table, and the number/plural rules (Amount::Locale)
    amount.ts              Amount
    ratio.ts               exact fractions; the arithmetic core every model uses
    display.ts             Amount::Display
    compact.ts             Amount::Compact
    parser.ts              Amount::Parser
    ui-parser.ts           Amount::UiParser
```

Tests mirror `src/` one-to-one under `tests/`, one assertion per test, with
shared fixtures in `tests/helpers/fixtures.ts`. Every test runs against a
manifest the gem actually exported (`tests/fixtures/manifest.json`, from
`tests/fixtures/registry.rb`), and every expected value is the gem's output
for that registry. CI exports the manifest again from each commit's gem and
fails if it differs, so the wire contract is held from both ends.
