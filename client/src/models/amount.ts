import type { Amounts } from "@/models/amounts.js";
import type { RegistryEntry } from "@/models/registry-entry.js";
import type {
  AmountDisplayFormatOptions,
  AmountToOptions,
  AmountUiOptions,
  AmountUnitLabelOptions,
  DecimalInput,
} from "@/types.js";

import { isDecimalInput } from "@/helpers/decimal-helper.js";
import { AmountError, errors } from "@/helpers/errors-helper.js";
import { Display } from "@/models/display.js";
import { Ratio } from "@/models/ratio.js";

/** The `v` of every `toHash` payload; `Amounts#load` refuses any other. */
const SERIALIZATION_VERSION = 1;

/**
 * A precise quantity of one registered type — the gem's `Amount`.
 *
 * An amount is an atomic `bigint` (a count of the type's smallest unit:
 * micro-USDC, cents, lamports, wei) plus the type it belongs to. Nothing
 * else is stored: the whole-unit value, every display string and every
 * conversion are derived from those two on demand, exactly.
 *
 * **Immutable.** An amount is frozen at construction, and every operation
 * returns a new one. Pass amounts around freely; nothing can change one
 * under you.
 *
 * **Typed.** Arithmetic and comparison stay within one type. Another type
 * is accepted only through a default rate the server registered
 * (`register_default_rate`) — there is no implicit conversion, and rates
 * are never inverted.
 *
 * **Exact.** No value ever passes through floating point. Multiplication,
 * division and conversion compute the exact result as a fraction and then
 * truncate toward zero to the atomic unit, as the gem does.
 *
 * The methods are grouped as the gem's concerns are: Calculable, Orderable,
 * Convertible, Allocatable, Serializable and Display.
 *
 * Build amounts through an {@link Amounts} client — `of`, `parse`,
 * `parseUi` or `load` — never with `new`.
 *
 * @example
 *   const price = amounts.of("USDC", "19.99");
 *   const total = price.multiply(3);          // USDC 59.97
 *   total.ui();                               // "$59.97"
 *   total.toJSON();                           // "USDC|59.970000"
 */
export class Amount {
  /** The client this amount was built by: its registry and default locale. */
  readonly amounts: Amounts;
  /** The type's registry entry: decimals, labels, templates, display units. */
  readonly registryEntry: RegistryEntry;
  /** The type's symbol, as registered in the gem (`"USDC"`). */
  readonly symbol: string;
  /**
   * The value in the type's smallest unit. `1_500_000n` is 1.50 for a type
   * with 6 decimals. A `bigint`, so it is exact at any size.
   */
  readonly atomic: bigint;
  /** The type's storage decimals: one whole unit is `10 ** decimals` atomic units. */
  readonly decimals: number;

  private readonly display: Display;

  /**
   * Internal: use {@link Amounts.of}, {@link Amounts.parse},
   * {@link Amounts.parseUi} or {@link Amounts.load}.
   *
   * @param amounts - the client building the amount
   * @param entry - the type's registry entry
   * @param atomic - the value in atomic units
   */
  constructor(amounts: Amounts, entry: RegistryEntry, atomic: bigint) {
    this.amounts = amounts;
    this.registryEntry = entry;
    this.symbol = entry.symbol;
    this.atomic = atomic;
    this.decimals = entry.decimals;
    this.display = new Display(this);
    Object.freeze(this);
  }

  /**
   * The exact value in whole units, as the gem's `BigDecimal#to_s("F")`
   * writes it: no trailing zeros, but always a point.
   *
   * Use it to hand the value to code that takes a decimal string (a form
   * field's initial value, a charting library). For display, use
   * {@link ui}; for the wire, {@link toJSON}.
   *
   * @example
   *   amounts.of("USDC", "1.50").decimal;  // "1.5"
   *   amounts.of("USDC", "2").decimal;     // "2.0"
   *   amounts.of("LOGS", 7n).decimal;      // "7.0"
   */
  get decimal(): string {
    const value = this.toRatio();

    return value.toDecimal();
  }

  /**
   * The exact value in whole units, as a {@link Ratio}: `atomic` over
   * `10 ** decimals`, reduced.
   *
   * @example
   *   amounts.of("USDC", "1.5").toRatio().toString();  // "3/2"
   */
  toRatio(): Ratio {
    const unit = Ratio.powerOfTen(this.decimals);

    return Ratio.of(this.atomic, unit.numerator);
  }

  // Calculable

  /**
   * The sum, in the receiver's type.
   *
   * An amount of another type is first converted with the registered
   * default rate from its type to the receiver's (as {@link to} would),
   * so the result is always in the receiver's type and atomic unit.
   *
   * @param other - an amount of the same type, or of a type with a default
   *   rate into this one
   * @returns a new amount in the receiver's type
   * @throws {@link AmountError} `TYPE_MISMATCH` when `other` is another type
   *   without a default rate into this one, or not an amount
   *
   * @example
   *   amounts.of("USDC", "1.50").add(amounts.of("USDC", "0.25"));  // USDC 1.75
   *
   * @example Across types, with a registered USD → USDC rate of 1
   *   amounts.of("USDC", "10").add(amounts.of("USD", "5"));  // USDC 15.00
   */
  add(other: Amount): Amount {
    const rhs = this.coerceToSelf(other);

    if (rhs === null) throw errors.typeMismatch(this.symbol, describeOperand(other));

    return this.build(this.atomic + rhs.atomic);
  }

  /**
   * The difference, in the receiver's type. Converts another type exactly
   * as {@link add} does.
   *
   * @param other - an amount of the same type, or of a type with a default
   *   rate into this one
   * @returns a new amount in the receiver's type
   * @throws {@link AmountError} `TYPE_MISMATCH`, as {@link add}
   *
   * @example
   *   amounts.of("USDC", "1").subtract(amounts.of("USDC", "0.25"));  // USDC 0.75
   */
  subtract(other: Amount): Amount {
    const rhs = this.coerceToSelf(other);

    if (rhs === null) throw errors.typeMismatch(this.symbol, describeOperand(other));

    return this.build(this.atomic - rhs.atomic);
  }

  /**
   * Multiplied by a scalar: the exact product, truncated toward zero to the
   * atomic unit.
   *
   * The scalar is read exactly: a decimal string as written, a `number`
   * through its string form (`0.1` is exactly one tenth), a `bigint` as
   * itself.
   *
   * @param scalar - a `bigint`, `number` or decimal string
   * @returns a new amount in the receiver's type
   * @throws {@link AmountError} `TYPE_MISMATCH` for a non-scalar (an amount
   *   included — multiplying two amounts has no unit), `INVALID_INPUT` for a
   *   string that isn't a decimal
   *
   * @example
   *   amounts.of("USDC", "1.25").multiply(2);            // USDC 2.50
   *   amounts.of("USDC", "100").multiply("0.075");       // USDC 7.50, a 7.5% fee
   *   amounts.of("USDC", "1").multiply("0.3333333");     // USDC 0.333333, truncated
   */
  multiply(scalar: DecimalInput): Amount {
    const factor = readScalar(scalar);
    const atomic = Ratio.of(this.atomic);
    const product = atomic.multiply(factor);

    return this.build(product.truncate());
  }

  /**
   * Divided by a scalar: the exact quotient, truncated toward zero to the
   * atomic unit. Use {@link split} instead when the parts must add back up.
   *
   * @param scalar - a `bigint`, `number` or decimal string
   * @returns a new amount in the receiver's type
   * @throws {@link AmountError} `ZERO_DIVISION`, `TYPE_MISMATCH` for a
   *   non-scalar, `INVALID_INPUT` for an unreadable string
   *
   * @example
   *   amounts.of("USDC", "10").divide(3);  // USDC 3.333333 — the 0.000001 left over is dropped
   */
  divide(scalar: DecimalInput): Amount;
  /**
   * Divided by an amount of the same type: their exact ratio, a unitless
   * {@link Ratio}. Never rounded.
   *
   * @param other - an amount of the same type
   * @returns the exact fraction `this / other`
   * @throws {@link AmountError} `TYPE_MISMATCH` for another type (no
   *   conversion), `ZERO_DIVISION` when `other` is zero
   *
   * @example
   *   const share = amounts.of("USDC", "25").divide(amounts.of("USDC", "200"));
   *   share.toString();     // "1/8"
   *   share.toFixed(4);     // "0.1250"
   */
  divide(other: Amount): Ratio;
  divide(other: Amount | DecimalInput): Amount | Ratio {
    if (other instanceof Amount) return this.ratio(other);

    const divisor = readScalar(other);

    if (divisor.isZero()) throw errors.zeroDivision();

    const atomic = Ratio.of(this.atomic);
    const quotient = atomic.divide(divisor);

    return this.build(quotient.truncate());
  }

  /**
   * The same amount without its sign.
   *
   * @example
   *   amounts.of("USDC", "-5").abs();  // USDC 5.00
   */
  abs(): Amount {
    return this.build(this.atomic < 0n ? -this.atomic : this.atomic);
  }

  /**
   * The same amount with its sign flipped (the gem's unary `-`).
   *
   * @example
   *   amounts.of("USDC", "5").negate();  // USDC -5.00
   */
  negate(): Amount {
    return this.build(-this.atomic);
  }

  // Orderable

  /**
   * Whether `other` is an amount of the same type. Never converts.
   *
   * @param other - anything
   *
   * @example
   *   usdc.sameType(amounts.of("USDC", "2"));  // true
   *   usdc.sameType(amounts.of("USD", "2"));   // false
   */
  sameType(other: unknown): boolean {
    return other instanceof Amount && other.symbol === this.symbol;
  }

  /**
   * Orders two amounts, the gem's `<=>`: `-1` when the receiver is smaller,
   * `0` when equal, `1` when larger.
   *
   * Another type is converted through its default rate into the receiver's
   * type first. When the two can't be compared — no default rate, or
   * `other` isn't an amount — the result is `null` rather than an error,
   * so it can sit in a sort comparator behind a check.
   *
   * @param other - anything
   * @returns `-1`, `0`, `1`, or `null` when not comparable
   *
   * @example
   *   const balances = [b, a, c].sort((x, y) => x.compare(y) ?? 0);
   */
  compare(other: unknown): -1 | 0 | 1 | null {
    const comparable = this.coerceToSelf(other);

    if (comparable === null) return null;

    if (this.atomic < comparable.atomic) return -1;

    if (this.atomic > comparable.atomic) return 1;

    return 0;
  }

  /**
   * Whether `other` is the same type with the same atomic value, the gem's
   * `==`. Never converts: one USDC doesn't equal one USD, whatever the rate.
   * Use {@link compare} to compare values across types.
   *
   * @param other - anything
   *
   * @example
   *   amounts.of("USDC", "1.5").equals(amounts.parse("USDC|1.500000"));  // true
   *   amounts.of("USDC", "1").equals(amounts.of("USD", "1"));            // false
   */
  equals(other: unknown): boolean {
    return this.sameType(other) && (other as Amount).atomic === this.atomic;
  }

  /**
   * Whether the receiver is smaller than `other`, converting through a
   * default rate as {@link compare} does.
   *
   * @throws {@link AmountError} `NOT_COMPARABLE` when the two can't be
   *   compared, as Ruby's `Comparable` raises
   *
   * @example
   *   if (cost.greaterThan(balance)) showInsufficientFunds();
   */
  lessThan(other: Amount): boolean {
    return this.compareOrThrow(other) < 0;
  }

  /**
   * Whether the receiver is smaller than or equal to `other`.
   *
   * @throws {@link AmountError} `NOT_COMPARABLE`, as {@link lessThan}
   */
  lessThanOrEqual(other: Amount): boolean {
    return this.compareOrThrow(other) <= 0;
  }

  /**
   * Whether the receiver is larger than `other`.
   *
   * @throws {@link AmountError} `NOT_COMPARABLE`, as {@link lessThan}
   */
  greaterThan(other: Amount): boolean {
    return this.compareOrThrow(other) > 0;
  }

  /**
   * Whether the receiver is larger than or equal to `other`.
   *
   * @throws {@link AmountError} `NOT_COMPARABLE`, as {@link lessThan}
   */
  greaterThanOrEqual(other: Amount): boolean {
    return this.compareOrThrow(other) >= 0;
  }

  /** Whether the amount is exactly zero. */
  isZero(): boolean {
    return this.atomic === 0n;
  }

  /** Whether the amount is above zero. */
  isPositive(): boolean {
    return this.atomic > 0n;
  }

  /** Whether the amount is below zero. */
  isNegative(): boolean {
    return this.atomic < 0n;
  }

  // Convertible

  /**
   * The amount in another type.
   *
   * The whole-unit value is multiplied by the rate and truncated toward
   * zero to the target's atomic unit. The rate is `options.rate` when
   * given (a one-off quote), else the default rate the server registered
   * for this direction. Rates are directional and never inverted: a
   * USD → USDC rate doesn't convert USDC → USD.
   *
   * Converting to the receiver's own type returns an equal copy.
   *
   * @param symbol - the target type
   * @param options - `rate`: a `bigint`, `number` or decimal string to use
   *   instead of the default rate
   * @returns a new amount in the target type
   * @throws {@link AmountError} `NO_DEFAULT_RATE` without a rate,
   *   `UNKNOWN_TYPE` for an unregistered target, `INVALID_INPUT` for an
   *   unreadable rate
   *
   * @example With a registered USDC → SOL rate of 0.0066666666
   *   amounts.of("USDC", "100").to("SOL");  // SOL 0.666666660
   *
   * @example With a live quote
   *   amounts.of("USDC", "100").to("GOLD", { rate: quote.rate });
   */
  to(symbol: string, options: AmountToOptions = {}): Amount {
    if (symbol === this.symbol) return this.build(this.atomic);

    const registry = this.amounts.registry;
    const rate = options.rate ?? registry.defaultRate(this.symbol, symbol);
    const target = registry.lookup(symbol);
    const factor = Ratio.parse(rate);

    if (factor === null) throw errors.cannotParse(rate);

    const value = this.toRatio();
    const converted = value.multiply(factor);
    const scale = Ratio.powerOfTen(target.decimals);
    const atomic = converted.multiply(scale);

    return new Amount(this.amounts, target, atomic.truncate());
  }

  // Allocatable

  /**
   * Splits into `n` equal parts, and returns what's left over explicitly
   * instead of losing it.
   *
   * Every part is the same, rounded toward zero to the atomic unit, and
   * the remainder is what didn't divide evenly. The parts plus the
   * remainder always add back up to the receiver, sign included. Hand the
   * remainder to one party, or keep it, as your rules require.
   *
   * @param n - a positive integer
   * @returns `[parts, remainder]`
   * @throws {@link AmountError} `INVALID_ARGUMENT` unless `n` is a positive integer
   *
   * @example Splitting a bill three ways
   *   const [parts, remainder] = amounts.of("USD", "100").split(3);
   *   parts.map((part) => part.ui());  // ["$33.33", "$33.33", "$33.33"]
   *   remainder.ui();                  // "$0.01"
   */
  split(n: number): [Amount[], Amount] {
    if (!Number.isInteger(n) || n <= 0) throw errors.invalidArgument("n must be positive");

    const sign = this.sign();
    const magnitude = this.atomic * sign;
    const count = BigInt(n);
    const part = this.build(sign * (magnitude / count));
    const parts = Array.from({ length: n }, () => part);

    return [parts, this.build(sign * (magnitude % count))];
  }

  /**
   * Allocates in proportion to integer weights, and returns what's left
   * over explicitly.
   *
   * Each part is its share rounded toward zero to the atomic unit; the
   * remainder is what the rounding left. The parts plus the remainder
   * always add back up to the receiver, sign included. A zero weight gets
   * nothing.
   *
   * @param weights - non-negative integers (`number` or `bigint`), at least
   *   one of them positive
   * @returns `[parts, remainder]`, with one part per weight, in order
   * @throws {@link AmountError} `INVALID_ARGUMENT` for no weights, a negative
   *   or fractional weight, or weights summing to zero
   *
   * @example A 70 / 20 / 10 revenue share
   *   const [[creator, platform, referrer], remainder] =
   *     amounts.of("USDC", "99.99").allocate([70, 20, 10]);
   */
  allocate(weights: (number | bigint)[]): [Amount[], Amount] {
    if (weights.length === 0) throw errors.invalidArgument("weights must be non-empty");

    const integers = weights.map(readWeight);
    const total = integers.reduce((sum, weight) => sum + weight, 0n);

    if (total <= 0n) throw errors.invalidArgument("weights must sum to positive value");

    const sign = this.sign();
    const magnitude = this.atomic * sign;
    const allocations = integers.map((weight) => (magnitude * weight) / total);
    const allocated = allocations.reduce((sum, allocation) => sum + allocation, 0n);
    const parts = allocations.map((allocation) => this.build(sign * allocation));

    return [parts, this.build(sign * (magnitude - allocated))];
  }

  // Serializable

  /**
   * The versioned payload the gem's `to_h` writes. `atomic` is a string so
   * it survives any JSON parser; {@link Amounts.load} reads it back.
   *
   * @example
   *   amounts.of("USDC", "1.5").toHash();
   *   // { v: 1, atomic: "1500000", symbol: "USDC" }
   */
  toHash(): { v: 1; atomic: string; symbol: string } {
    return { v: SERIALIZATION_VERSION, atomic: this.atomic.toString(), symbol: this.symbol };
  }

  /**
   * The exact compact string the gem's `as_json` writes: the symbol, a
   * bar, and the value in whole units with exactly `decimals` places. It
   * ignores every display setting and never rounds, so
   * {@link Amounts.parse} — and the gem's `Amount.parse` — read it back
   * exactly.
   *
   * `JSON.stringify` calls it, so an amount inside a request body is
   * written in the format a Rails controller already reads.
   *
   * @example
   *   amounts.of("USDC", "1.5").toJSON();          // "USDC|1.500000"
   *   JSON.stringify({ price: amounts.of("USD", "9.99") });
   *   // '{"price":"USD|9.99"}'
   */
  toJSON(): string {
    return `${this.symbol}|${this.formatted()}`;
  }

  /**
   * The display-rounded compact string the gem's `to_s` writes: rounded to
   * the type's `ui_decimals` in the default direction, never localized,
   * no label. For logs and debugging; it can drop digits, so never use it
   * to round-trip — use {@link toJSON}.
   *
   * @example
   *   amounts.of("USDC", "1.239").toString();  // "USDC|1.23"
   */
  toString(): string {
    return this.display.toString();
  }

  /**
   * The exact value with exactly `decimals` places, no symbol: the number
   * part of {@link toJSON}.
   *
   * @example
   *   amounts.of("USDC", "1.5").formatted();  // "1.500000"
   *   amounts.of("LOGS", 5n).formatted();     // "5"
   */
  formatted(): string {
    return this.display.formatted();
  }

  // Display

  /**
   * The amount for people: rounded to the display decimals, in a locale's
   * number format, with its label placed by the type's template.
   *
   * See {@link AmountUiOptions} for every option: `unit`, `direction`,
   * `decorated`, `trimZeros`, `locale` and `compact`.
   *
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`, `UNKNOWN_LOCALE`,
   *   `INVALID_ARGUMENT` for a bad `compact` option
   *
   * @example
   *   const amount = amounts.of("USD", "1500.5");
   *   amount.ui();                        // "$1500.50" — plain: no locale, no delimiters
   *   amount.ui({ locale: "en" });        // "$1,500.50"
   *   amount.ui({ locale: "de" });        // "$1.500,50", or the locale's own template
   *   amount.ui({ compact: true });       // "$1.5K"
   *   amount.ui({ decorated: false });    // "1500.50"
   *
   * @example A display unit
   *   amounts.of("GOLD", "1").ui({ unit: "gram" });  // "31.10 g"
   */
  ui(options: AmountUiOptions = {}): string {
    return this.display.ui(options);
  }

  /**
   * The unit label alone, for a column header, a chip or an input
   * adornment that renders the label apart from the number. Translated in
   * a locale; a plural label agrees with `count` when one is given.
   *
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`, `UNKNOWN_LOCALE`,
   *   `INVALID_INPUT` for an unreadable count
   *
   * @example
   *   usdc.unitLabel();                          // "$"
   *   searches.unitLabel({ count: 1 });          // "search"
   *   searches.unitLabel({ count: 3 });          // "searches"
   *   gold.unitLabel({ unit: "gram", locale: "de" });  // "Gramm"
   */
  unitLabel(options: AmountUnitLabelOptions = {}): string {
    return this.display.unitLabel(options);
  }

  /**
   * The template decorated {@link ui} output uses: `%n` is the number and
   * `%u` the label. For laying out the number and label yourself in the
   * order the type and locale expect.
   *
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`, `UNKNOWN_LOCALE`
   *
   * @example
   *   usd.displayFormat();                  // "%u%n"
   *   sol.displayFormat();                  // "%n %u"
   *   eur.displayFormat({ locale: "de" });  // "%n %u" (with a non-breaking space)
   */
  displayFormat(options: AmountDisplayFormatOptions = {}): string {
    return this.display.displayFormat(options);
  }

  /**
   * The exact value in one of the type's display units, as a decimal
   * string. Display units only change how an amount is shown — the amount
   * is still the same type.
   *
   * @param unit - a display unit the type registered
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`
   *
   * @example One troy ounce, with a gram unit of scale 31.1034768
   *   amounts.of("GOLD", "1").inUnit("gram");  // "31.1034768"
   */
  inUnit(unit: string): string {
    return this.display.inUnit(unit);
  }

  /** A new amount of the receiver's type: what every operation returns. */
  private build(atomic: bigint): Amount {
    return new Amount(this.amounts, this.registryEntry, atomic);
  }

  /** `1n`, `-1n` or `0n`. */
  private sign(): bigint {
    if (this.atomic > 0n) return 1n;

    if (this.atomic < 0n) return -1n;

    return 0n;
  }

  /**
   * `other` in the receiver's type: itself when the types match, converted
   * through a default rate when one exists, else `null`. The gem's
   * `coerce_other_to_self_type`.
   */
  private coerceToSelf(other: unknown): Amount | null {
    if (!(other instanceof Amount)) return null;

    if (other.symbol === this.symbol) return other;

    try {
      return other.to(this.symbol);
    } catch (error) {
      if (error instanceof AmountError && error.code === "NO_DEFAULT_RATE") return null;

      throw error;
    }
  }

  /** `compare`, raising `NOT_COMPARABLE` where it would return `null`. */
  private compareOrThrow(other: Amount): -1 | 0 | 1 {
    const order = this.compare(other);

    if (order === null) throw errors.notComparable(kindOf(other));

    return order;
  }

  /** The exact ratio of two amounts of the same type. */
  private ratio(other: Amount): Ratio {
    if (!this.sameType(other)) throw errors.typeMismatch(this.symbol, describeOperand(other));

    if (other.isZero()) throw errors.zeroDivision();

    return Ratio.of(this.atomic, other.atomic);
  }
}

/** How an operand is named in a type mismatch: an amount by its symbol, else by its type. */
function describeOperand(value: unknown): string {
  if (value instanceof Amount) return value.symbol;

  if (value === null) return "null";

  return typeof value;
}

/** What kind of value an operand is, as Ruby names its class: `"Amount"`, `"object"`. */
function kindOf(value: unknown): string {
  if (value instanceof Amount) return "Amount";

  return describeOperand(value);
}

/**
 * Reads a scalar exactly, as the gem's `ensure_scalar!` and
 * `coerce_decimal` do together.
 */
function readScalar(scalar: unknown): Ratio {
  if (!isDecimalInput(scalar)) throw errors.notScalar(kindOf(scalar));

  const value = Ratio.parse(scalar);

  if (value === null) throw errors.cannotParse(scalar);

  return value;
}

/** Reads one allocation weight: a non-negative integer. */
function readWeight(weight: number | bigint): bigint {
  const valid = typeof weight === "bigint" || Number.isInteger(weight);

  if (!valid) throw errors.invalidArgument("weights must be non-negative integers");

  const integer = BigInt(weight);

  if (integer < 0n) throw errors.invalidArgument("weights must be non-negative integers");

  return integer;
}
