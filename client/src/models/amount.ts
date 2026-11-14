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

const SERIALIZATION_VERSION = 1;

/**
 * A precise quantity of a registered type: an atomic `bigint` in the
 * type's smallest unit. The gem's `Amount`, with its concerns as the
 * sections below. Immutable: every operation returns a new amount.
 *
 * Build one through an `Amounts` client (`amounts.of`, `parse`,
 * `parseUi`, `load`), never with `new`.
 */
export class Amount {
  /** The client this amount was built by; its registry and default locale. */
  readonly amounts: Amounts;
  readonly registryEntry: RegistryEntry;
  readonly symbol: string;
  readonly atomic: bigint;
  /** Storage decimals of the type. */
  readonly decimals: number;

  private readonly display: Display;

  constructor(amounts: Amounts, entry: RegistryEntry, atomic: bigint) {
    this.amounts = amounts;
    this.registryEntry = entry;
    this.symbol = entry.symbol;
    this.atomic = atomic;
    this.decimals = entry.decimals;
    this.display = new Display(this);
    Object.freeze(this);
  }

  /** The exact value in whole units, as `BigDecimal#to_s("F")` writes it: `"1.5"`, `"1.0"`. */
  get decimal(): string {
    const value = this.toRatio();

    return value.toDecimal();
  }

  /** The exact value in whole units, as a fraction. */
  toRatio(): Ratio {
    const unit = Ratio.powerOfTen(this.decimals);

    return Ratio.of(this.atomic, unit.numerator);
  }

  // Calculable

  /**
   * The sum, in the receiver's type. Another type converts through its
   * registered default rate.
   *
   * @throws AmountError TYPE_MISMATCH without one
   */
  add(other: Amount): Amount {
    const rhs = this.coerceToSelf(other);

    if (rhs === null) throw errors.typeMismatch(this.symbol, describeOperand(other));

    return this.build(this.atomic + rhs.atomic);
  }

  /** @throws AmountError TYPE_MISMATCH, as `add` */
  subtract(other: Amount): Amount {
    const rhs = this.coerceToSelf(other);

    if (rhs === null) throw errors.typeMismatch(this.symbol, describeOperand(other));

    return this.build(this.atomic - rhs.atomic);
  }

  /**
   * Multiplied by a scalar, exactly, then truncated toward zero.
   *
   * @throws AmountError TYPE_MISMATCH for a non-scalar, INVALID_INPUT for an unreadable one
   */
  multiply(scalar: DecimalInput): Amount {
    const factor = readScalar(scalar);
    const atomic = Ratio.of(this.atomic);
    const product = atomic.multiply(factor);

    return this.build(product.truncate());
  }

  /**
   * By a scalar: the exact quotient, truncated toward zero. By an amount
   * of the same type: their exact ratio.
   *
   * @throws AmountError ZERO_DIVISION, TYPE_MISMATCH, INVALID_INPUT
   */
  divide(other: Amount): Ratio;
  divide(scalar: DecimalInput): Amount;
  divide(other: Amount | DecimalInput): Amount | Ratio {
    if (other instanceof Amount) return this.ratio(other);

    const divisor = readScalar(other);

    if (divisor.isZero()) throw errors.zeroDivision();

    const atomic = Ratio.of(this.atomic);
    const quotient = atomic.divide(divisor);

    return this.build(quotient.truncate());
  }

  abs(): Amount {
    return this.build(this.atomic < 0n ? -this.atomic : this.atomic);
  }

  negate(): Amount {
    return this.build(-this.atomic);
  }

  // Orderable

  sameType(other: unknown): boolean {
    return other instanceof Amount && other.symbol === this.symbol;
  }

  /**
   * -1, 0 or 1, converting another type through its default rate; `null`
   * when the two can't be compared (`<=>`).
   */
  compare(other: unknown): -1 | 0 | 1 | null {
    const comparable = this.coerceToSelf(other);

    if (comparable === null) return null;

    if (this.atomic < comparable.atomic) return -1;

    if (this.atomic > comparable.atomic) return 1;

    return 0;
  }

  /** Same type and atomic value. No conversion (`==`). */
  equals(other: unknown): boolean {
    return this.sameType(other) && (other as Amount).atomic === this.atomic;
  }

  /** @throws AmountError NOT_COMPARABLE */
  lessThan(other: Amount): boolean {
    return this.compareOrThrow(other) < 0;
  }

  /** @throws AmountError NOT_COMPARABLE */
  lessThanOrEqual(other: Amount): boolean {
    return this.compareOrThrow(other) <= 0;
  }

  /** @throws AmountError NOT_COMPARABLE */
  greaterThan(other: Amount): boolean {
    return this.compareOrThrow(other) > 0;
  }

  /** @throws AmountError NOT_COMPARABLE */
  greaterThanOrEqual(other: Amount): boolean {
    return this.compareOrThrow(other) >= 0;
  }

  isZero(): boolean {
    return this.atomic === 0n;
  }

  isPositive(): boolean {
    return this.atomic > 0n;
  }

  isNegative(): boolean {
    return this.atomic < 0n;
  }

  // Convertible

  /**
   * In another type: the value times the rate, truncated to the target's
   * atomic unit. Uses `rate` when given, else the registered directional
   * default rate.
   *
   * @throws AmountError NO_DEFAULT_RATE, UNKNOWN_TYPE, INVALID_INPUT (rate)
   */
  to(symbol: string, options: AmountToOptions = {}): Amount {
    if (symbol === this.symbol) return this.build(this.atomic);

    const registry = this.amounts.registry;
    const rate = options.rate ?? registry.defaultRate(this.symbol, symbol);
    const target = registry.lookup(symbol);
    const factor = Ratio.parse(rate);

    if (factor === null) throw errors.cannotParse(rate);

    const converted = this.toRatio().multiply(factor);
    const scale = Ratio.powerOfTen(target.decimals);
    const atomic = converted.multiply(scale);

    return new Amount(this.amounts, target, atomic.truncate());
  }

  // Allocatable

  /**
   * `n` equal parts and the leftover. The parts plus the remainder always
   * sum to the receiver, sign included.
   *
   * @throws AmountError INVALID_ARGUMENT unless `n` is a positive integer
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
   * Parts proportional to integer weights, and the leftover. The parts
   * plus the remainder always sum to the receiver, sign included.
   *
   * @throws AmountError INVALID_ARGUMENT for empty or negative weights, or weights summing to zero
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

  /** `{ v: 1, atomic: "1500000", symbol: "USDC" }`, read back by `Amounts#load`. */
  toHash(): { v: 1; atomic: string; symbol: string } {
    return { v: SERIALIZATION_VERSION, atomic: this.atomic.toString(), symbol: this.symbol };
  }

  /**
   * `"USDC|1.500000"`: whole units with exactly `decimals` places, read
   * back exactly by `Amounts#parse`. `JSON.stringify` writes an amount
   * through it, as the gem's `as_json`.
   */
  toJSON(): string {
    return `${this.symbol}|${this.formatted()}`;
  }

  /** `"USDC|1.50"`: rounded down to the display decimals, never localized (the gem's `to_s`). */
  toString(): string {
    return this.display.toString();
  }

  /** `"1.500000"`: the exact value with exactly `decimals` places. */
  formatted(): string {
    return this.display.formatted();
  }

  // Display

  /** For people: `"$1.50"`, `"1.500,50 €"`, `"$1.5M"`. See `Display#ui`. */
  ui(options: AmountUiOptions = {}): string {
    return this.display.ui(options);
  }

  /** The unit label alone. See `Display#unitLabel`. */
  unitLabel(options: AmountUnitLabelOptions = {}): string {
    return this.display.unitLabel(options);
  }

  /** The template decorated output uses. See `Display#displayFormat`. */
  displayFormat(options: AmountDisplayFormatOptions = {}): string {
    return this.display.displayFormat(options);
  }

  /** The exact value in a display unit. See `Display#inUnit`. */
  inUnit(unit: string): string {
    return this.display.inUnit(unit);
  }

  private build(atomic: bigint): Amount {
    return new Amount(this.amounts, this.registryEntry, atomic);
  }

  private sign(): bigint {
    if (this.atomic > 0n) return 1n;

    if (this.atomic < 0n) return -1n;

    return 0n;
  }

  /** `other` in the receiver's type, through a default rate when needed, else `null`. */
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

  private compareOrThrow(other: Amount): -1 | 0 | 1 {
    const order = this.compare(other);

    if (order === null) throw errors.notComparable(kindOf(other));

    return order;
  }

  private ratio(other: Amount): Ratio {
    if (!this.sameType(other)) throw errors.typeMismatch(this.symbol, describeOperand(other));

    if (other.isZero()) throw errors.zeroDivision();

    return Ratio.of(this.atomic, other.atomic);
  }
}

/** How an operand is named in an error: an amount by its symbol, else by its type. */
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

function readScalar(scalar: unknown): Ratio {
  if (!isDecimalInput(scalar)) throw errors.notScalar(kindOf(scalar));

  const value = Ratio.parse(scalar);

  if (value === null) throw errors.cannotParse(scalar);

  return value;
}

function readWeight(weight: number | bigint): bigint {
  const valid = typeof weight === "bigint" || Number.isInteger(weight);

  if (!valid) throw errors.invalidArgument("weights must be non-negative integers");

  const integer = BigInt(weight);

  if (integer < 0n) throw errors.invalidArgument("weights must be non-negative integers");

  return integer;
}
