import type { DecimalInput, RoundingDirection } from "@/types.js";

import { decimalText, formatScaled, parseDecimal } from "@/helpers/decimal-helper.js";
import { errors } from "@/helpers/errors-helper.js";

/**
 * An exact fraction of two `bigint`s.
 *
 * It is the client's arithmetic core. Everything the gem holds as a
 * `BigDecimal` or `Rational` — a UI value, a scalar, a rate, a display-unit
 * scale, a number on its way to the screen — is a `Ratio` here, so nothing
 * is rounded until a caller asks for digits, and then only once.
 *
 * It is also public, as the result of dividing one amount by another
 * ({@link Amount.divide}): a unitless share or rate that stays exact,
 * where Ruby's `BigDecimal` quotient would be rounded to an internal
 * precision.
 *
 * Always reduced, with the sign on the numerator and a positive
 * denominator, so equal values have equal fields. Immutable.
 *
 * @example
 *   const share = amounts.of("USDC", "25").divide(amounts.of("USDC", "200"));
 *   share.numerator;     // 1n
 *   share.denominator;   // 8n
 *   share.toFixed(2);    // "0.12"
 *   share.toString();    // "1/8"
 */
export class Ratio {
  /** The numerator, carrying the sign. */
  readonly numerator: bigint;
  /** The denominator, always positive. */
  readonly denominator: bigint;

  private constructor(numerator: bigint, denominator: bigint) {
    this.numerator = numerator;
    this.denominator = denominator;
    Object.freeze(this);
  }

  /**
   * The fraction `numerator / denominator`, reduced, with the sign moved
   * to the numerator.
   *
   * @param numerator - any integer
   * @param denominator - any non-zero integer; defaults to `1n`
   * @throws {@link AmountError} `ZERO_DIVISION` for a zero denominator
   *
   * @example
   *   Ratio.of(10n, 4n).toString();  // "5/2"
   *   Ratio.of(1n, -2n).toString();  // "-1/2"
   */
  static of(numerator: bigint, denominator = 1n): Ratio {
    if (denominator === 0n) throw errors.zeroDivision();

    const sign = denominator < 0n ? -1n : 1n;
    const divisor = gcd(abs(numerator), abs(denominator));

    return new Ratio((sign * numerator) / divisor, (sign * denominator) / divisor);
  }

  /**
   * `10 ** exponent`. A negative exponent gives a fraction.
   *
   * @param exponent - any integer
   *
   * @example
   *   Ratio.powerOfTen(3).toString();   // "1000/1"
   *   Ratio.powerOfTen(-2).toString();  // "1/100"
   */
  static powerOfTen(exponent: number): Ratio {
    const power = 10n ** BigInt(Math.abs(exponent));

    return exponent < 0 ? Ratio.of(1n, power) : Ratio.of(power);
  }

  /**
   * Reads a decimal exactly, as the gem's `Amount.coerce_decimal` does.
   *
   * - a `string` in Ruby's `BigDecimal` grammar: a sign, `_` between
   *   digits, a bare leading or trailing point, an exponent, surrounding
   *   whitespace
   * - a `number` through its string form, so `0.1` is exactly `1/10`
   * - a `bigint` as itself
   *
   * @param value - the decimal to read
   * @returns the exact value, or `null` when the input isn't a decimal
   *   (letters, `NaN`, `Infinity`, an object)
   *
   * @example
   *   Ratio.parse("0.1")?.toString();    // "1/10"
   *   Ratio.parse(0.1)?.toString();      // "1/10"
   *   Ratio.parse("1.5e2")?.toString();  // "150/1"
   *   Ratio.parse("abc");                // null
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

  /** The exact sum. */
  add(other: Ratio): Ratio {
    const numerator = this.numerator * other.denominator + other.numerator * this.denominator;

    return Ratio.of(numerator, this.denominator * other.denominator);
  }

  /** The exact difference. */
  subtract(other: Ratio): Ratio {
    const negated = other.negate();

    return this.add(negated);
  }

  /** The exact product. */
  multiply(other: Ratio): Ratio {
    return Ratio.of(this.numerator * other.numerator, this.denominator * other.denominator);
  }

  /**
   * The exact quotient.
   *
   * @throws {@link AmountError} `ZERO_DIVISION` when `other` is zero
   */
  divide(other: Ratio): Ratio {
    return Ratio.of(this.numerator * other.denominator, this.denominator * other.numerator);
  }

  /** The same value with its sign flipped. */
  negate(): Ratio {
    return Ratio.of(-this.numerator, this.denominator);
  }

  /** The same value without its sign. */
  abs(): Ratio {
    return Ratio.of(abs(this.numerator), this.denominator);
  }

  /**
   * Orders two values: `-1` when the receiver is smaller, `0` when equal,
   * `1` when larger.
   */
  compare(other: Ratio): -1 | 0 | 1 {
    const left = this.numerator * other.denominator;
    const right = other.numerator * this.denominator;

    if (left < right) return -1;

    if (left > right) return 1;

    return 0;
  }

  /** Whether the two are the same value, however they were written. */
  equals(other: Ratio): boolean {
    return this.numerator === other.numerator && this.denominator === other.denominator;
  }

  /** Whether the value is exactly zero. */
  isZero(): boolean {
    return this.numerator === 0n;
  }

  /**
   * The integer part, toward zero (Ruby's `to_i` and `truncate`): how the
   * gem turns an exact product, quotient or conversion into atomic units.
   *
   * @example
   *   Ratio.of(-7n, 2n).truncate();  // -3n
   */
  truncate(): bigint {
    return this.numerator / this.denominator;
  }

  /**
   * The greatest integer not above the value, toward negative infinity.
   *
   * @example
   *   Ratio.of(-7n, 2n).floor();  // -4n
   */
  floor(): bigint {
    const truncated = this.truncate();
    const exact = truncated * this.denominator === this.numerator;

    return this.numerator < 0n && !exact ? truncated - 1n : truncated;
  }

  /**
   * The least integer not below the value, toward positive infinity.
   *
   * @example
   *   Ratio.of(7n, 2n).ceil();  // 4n
   */
  ceil(): bigint {
    const truncated = this.truncate();
    const exact = truncated * this.denominator === this.numerator;

    return this.numerator > 0n && !exact ? truncated + 1n : truncated;
  }

  /**
   * Rounded to `places` decimals in `direction` — the gem's
   * `Display.round`, which every display string goes through. A negative
   * `places` rounds to tens, hundreds, and so on. Anything but `"ceil"`
   * rounds down, toward negative infinity.
   *
   * @param places - decimal places to keep; negative for tens, hundreds, ...
   * @param direction - `"floor"` (the default) or `"ceil"`
   * @returns the rounded value, still exact
   *
   * @example
   *   Ratio.parse("1.239")!.round(2).toString();          // "123/100"
   *   Ratio.parse("1.231")!.round(2, "ceil").toString();  // "31/25", 1.24
   *   Ratio.of(123n).round(-1).toString();                // "120/1"
   */
  round(places: number, direction: RoundingDirection = "floor"): Ratio {
    const factor = Ratio.powerOfTen(places);
    const scaled = this.multiply(factor);
    const rounded = direction === "ceil" ? scaled.ceil() : scaled.floor();
    const integer = Ratio.of(rounded);

    return integer.divide(factor);
  }

  /**
   * Rounded to `places` decimals in `direction`, as {@link round} rounds,
   * and written with exactly `places` digits after the point.
   *
   * @param places - a non-negative integer
   * @param direction - `"floor"` (the default) or `"ceil"`
   * @returns the digits, with a `-` for a negative value
   * @throws {@link AmountError} `INVALID_ARGUMENT` unless `places` is a
   *   non-negative integer
   *
   * @example
   *   Ratio.of(10n, 3n).toFixed(4);          // "3.3333"
   *   Ratio.of(10n, 3n).toFixed(4, "ceil");  // "3.3334"
   *   Ratio.of(1n, 8n).toFixed(0);           // "0"
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
   * The exact value as the gem's `BigDecimal#to_s("F")` writes it: no
   * trailing zeros, but always a point. Only for values with a finite
   * decimal form — every amount, rate and scale has one.
   *
   * @throws {@link AmountError} `INVALID_ARGUMENT` for a repeating value
   *   (`1/3`); use {@link toFixed} for those
   *
   * @example
   *   Ratio.of(3n, 20n).toDecimal();  // "0.15"
   *   Ratio.of(2n).toDecimal();       // "2.0"
   */
  toDecimal(): string {
    const places = terminatingPlaces(this.denominator);

    if (places === null) {
      throw errors.invalidArgument(`${this.toString()} has no exact decimal form`);
    }

    const fixed = this.toFixed(places);

    return places === 0 ? `${fixed}.0` : fixed;
  }

  /**
   * The fraction as `"numerator/denominator"`, always both parts.
   *
   * @example
   *   Ratio.of(10n, 3n).toString();  // "10/3"
   *   Ratio.of(4n).toString();       // "4/1"
   */
  toString(): string {
    return `${this.numerator}/${this.denominator}`;
  }
}

function abs(value: bigint): bigint {
  return value < 0n ? -value : value;
}

/** The greatest common divisor, by Euclid; `1n` for two zeros. */
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

/** How many times `factor` divides `value`. */
function factorCount(value: bigint, factor: bigint): number {
  let remaining = value;
  let count = 0;

  while (remaining % factor === 0n) {
    remaining /= factor;
    count += 1;
  }

  return count;
}
