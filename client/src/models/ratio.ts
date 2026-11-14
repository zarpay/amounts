import type { DecimalInput, RoundingDirection } from "@/types.js";

import { decimalText, formatScaled, parseDecimal } from "@/helpers/decimal-helper.js";
import { errors } from "@/helpers/errors-helper.js";

/**
 * An exact fraction of two `bigint`s.
 *
 * It is the arithmetic core: every value the gem holds as a `BigDecimal` or
 * `Rational` — a UI value, a scalar, a rate, a display-unit scale, a
 * displayed number — is a `Ratio` here, so nothing is ever rounded until a
 * caller asks for digits. It is also the public result of
 * `Amount#divide(Amount)`.
 *
 * Always reduced, with the sign on the numerator, so equal values have
 * equal fields.
 */
export class Ratio {
  /** Carries the sign. */
  readonly numerator: bigint;
  /** Always positive. */
  readonly denominator: bigint;

  private constructor(numerator: bigint, denominator: bigint) {
    this.numerator = numerator;
    this.denominator = denominator;
    Object.freeze(this);
  }

  /**
   * The fraction `numerator / denominator`, reduced.
   *
   * @throws AmountError ZERO_DIVISION for a zero denominator
   */
  static of(numerator: bigint, denominator = 1n): Ratio {
    if (denominator === 0n) throw errors.zeroDivision();

    const sign = denominator < 0n ? -1n : 1n;
    const divisor = gcd(abs(numerator), abs(denominator));

    return new Ratio((sign * numerator) / divisor, (sign * denominator) / divisor);
  }

  /** `10 ** exponent`; a negative exponent is a fraction (`10 ** -2` is `1/100`). */
  static powerOfTen(exponent: number): Ratio {
    const power = 10n ** BigInt(Math.abs(exponent));

    return exponent < 0 ? Ratio.of(1n, power) : Ratio.of(power);
  }

  /**
   * Reads a decimal exactly, as the gem's `Amount.coerce_decimal` does:
   * a `string` in `BigDecimal`'s grammar, a `number` through its string
   * form, a `bigint` as itself.
   *
   * @returns the value, or `null` when the input is not a decimal
   */
  static parse(value: DecimalInput): Ratio | null {
    const text = decimalText(value);

    if (text === null) return null;

    const decimal = parseDecimal(text);

    if (decimal === null) return null;

    const power = Ratio.powerOfTen(-decimal.scale);
    const coefficient = Ratio.of(decimal.coefficient);

    return coefficient.multiply(power);
  }

  add(other: Ratio): Ratio {
    const numerator = this.numerator * other.denominator + other.numerator * this.denominator;

    return Ratio.of(numerator, this.denominator * other.denominator);
  }

  subtract(other: Ratio): Ratio {
    const negated = other.negate();

    return this.add(negated);
  }

  multiply(other: Ratio): Ratio {
    return Ratio.of(this.numerator * other.numerator, this.denominator * other.denominator);
  }

  /** @throws AmountError ZERO_DIVISION when `other` is zero */
  divide(other: Ratio): Ratio {
    return Ratio.of(this.numerator * other.denominator, this.denominator * other.numerator);
  }

  negate(): Ratio {
    return Ratio.of(-this.numerator, this.denominator);
  }

  abs(): Ratio {
    return Ratio.of(abs(this.numerator), this.denominator);
  }

  /** -1, 0 or 1. */
  compare(other: Ratio): -1 | 0 | 1 {
    const left = this.numerator * other.denominator;
    const right = other.numerator * this.denominator;

    if (left < right) return -1;

    if (left > right) return 1;

    return 0;
  }

  equals(other: Ratio): boolean {
    return this.numerator === other.numerator && this.denominator === other.denominator;
  }

  isZero(): boolean {
    return this.numerator === 0n;
  }

  /** The integer part, toward zero (Ruby's `to_i` and `truncate`). */
  truncate(): bigint {
    return this.numerator / this.denominator;
  }

  /** The greatest integer not above the value. */
  floor(): bigint {
    const truncated = this.truncate();
    const exact = truncated * this.denominator === this.numerator;

    return this.numerator < 0n && !exact ? truncated - 1n : truncated;
  }

  /** The least integer not below the value. */
  ceil(): bigint {
    const truncated = this.truncate();
    const exact = truncated * this.denominator === this.numerator;

    return this.numerator > 0n && !exact ? truncated + 1n : truncated;
  }

  /**
   * Rounded to `places` decimals in `direction`; a negative `places`
   * rounds to tens, hundreds, ... The gem's `Display.round`: anything but
   * `"ceil"` rounds down, toward negative infinity.
   */
  round(places: number, direction: RoundingDirection = "floor"): Ratio {
    const factor = Ratio.powerOfTen(places);
    const scaled = this.multiply(factor);
    const rounded = direction === "ceil" ? scaled.ceil() : scaled.floor();
    const integer = Ratio.of(rounded);

    return integer.divide(factor);
  }

  /**
   * Rounded to `places` decimals in `direction`, as `ui` rounds, written
   * with exactly `places` digits after the point.
   *
   * @throws AmountError INVALID_ARGUMENT unless `places` is a non-negative integer
   */
  toFixed(places: number, direction: RoundingDirection = "floor"): string {
    if (!Number.isInteger(places) || places < 0) {
      throw errors.invalidArgument("places must be a non-negative integer");
    }

    const factor = Ratio.powerOfTen(places);
    const scaled = this.multiply(factor);
    const rounded = direction === "ceil" ? scaled.ceil() : scaled.floor();

    return formatScaled(rounded, places);
  }

  /**
   * The exact value as `BigDecimal#to_s("F")` writes it: no trailing
   * zeros, but always a point (`"1.5"`, `"1.0"`, `"-0.25"`).
   *
   * @throws AmountError INVALID_ARGUMENT when the value has no finite decimal form (`1/3`)
   */
  toDecimal(): string {
    const places = terminatingPlaces(this.denominator);

    if (places === null)
      throw errors.invalidArgument(`${this.toString()} has no exact decimal form`);

    const fixed = this.toFixed(places);

    return places === 0 ? `${fixed}.0` : fixed;
  }

  /** `"10/3"`. */
  toString(): string {
    return `${this.numerator}/${this.denominator}`;
  }
}

function abs(value: bigint): bigint {
  return value < 0n ? -value : value;
}

function gcd(left: bigint, right: bigint): bigint {
  let a = left;
  let b = right;

  while (b !== 0n) {
    [a, b] = [b, a % b];
  }

  return a === 0n ? 1n : a;
}

/**
 * The fewest decimal places that write `1 / denominator` exactly, or `null`
 * when it repeats: a reduced fraction terminates only when its denominator
 * has no prime factor but 2 and 5, and then needs as many places as the
 * larger of the two powers.
 */
function terminatingPlaces(denominator: bigint): number | null {
  const twos = factorCount(denominator, 2n);
  const fives = factorCount(denominator, 5n);
  const rest = denominator / (2n ** BigInt(twos) * 5n ** BigInt(fives));

  return rest === 1n ? Math.max(twos, fives) : null;
}

function factorCount(value: bigint, factor: bigint): number {
  let remaining = value;
  let count = 0;

  while (remaining % factor === 0n) {
    remaining /= factor;
    count += 1;
  }

  return count;
}
