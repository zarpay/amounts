/**
 * Exact decimal strings, in and out.
 *
 * Reading follows Ruby's `BigDecimal(String)` grammar, because that is what
 * the gem reads a UI value, scalar or rate with: surrounding whitespace, a
 * sign, `_` between digits, a bare leading or trailing point (`.5`, `5.`)
 * and an exponent (`1.5e2`). Writing never rounds: the caller decides the
 * digits, and these functions only place the point.
 */

import type { DecimalInput, ScaledDecimal } from "@/types.js";

const DECIMAL = /^\s*([+-])?(\d(?:_?\d)*)?(?:\.(\d(?:_?\d)*)?)?(?:[eE]([+-]?\d+))?\s*$/;

/**
 * The largest exponent read. Ruby's `BigDecimal` accepts more, but a
 * `bigint` of `10 ** 1e9` would hang a browser tab; no amount needs it.
 */
const MAX_EXPONENT = 10_000;

/**
 * Reads a decimal string exactly.
 *
 * @returns the decimal, or `null` when the text is not one
 */
export function parseDecimal(text: string): ScaledDecimal | null {
  const match = DECIMAL.exec(text);

  if (!match) return null;

  const [, sign, whole = "", fraction = "", exponent = "0"] = match;

  if (whole === "" && fraction === "") return null;

  const power = Number(exponent);

  if (Math.abs(power) > MAX_EXPONENT) return null;

  const wholeDigits = whole.replace(/_/g, "");
  const fractionDigits = fraction.replace(/_/g, "");
  const magnitude = BigInt(`${wholeDigits}${fractionDigits}`);
  const coefficient = sign === "-" ? -magnitude : magnitude;
  const scale = fractionDigits.length - power;

  return { coefficient, scale };
}

/**
 * The text a decimal input is read from: a `number` through its string
 * form (as the gem reads a `Float`), a `bigint` as its digits.
 *
 * @returns the text, or `null` for a non-finite number or another type
 */
export function decimalText(value: unknown): string | null {
  if (typeof value === "string") return value;

  if (typeof value === "bigint") return value.toString();

  if (typeof value === "number" && Number.isFinite(value)) return String(value);

  return null;
}

/** Whether a value is one `DecimalInput` accepts at all. */
export function isDecimalInput(value: unknown): value is DecimalInput {
  return typeof value === "string" || typeof value === "bigint" || typeof value === "number";
}

/**
 * Writes `coefficient / 10 ** places` with exactly `places` digits after
 * the point: `formatScaled(-150n, 2)` is `"-1.50"`.
 */
export function formatScaled(coefficient: bigint, places: number): string {
  const negative = coefficient < 0n;
  const magnitude = negative ? -coefficient : coefficient;
  const digits = magnitude.toString().padStart(places + 1, "0");
  const sign = negative ? "-" : "";

  if (places === 0) return `${sign}${digits}`;

  const whole = digits.slice(0, digits.length - places);
  const fraction = digits.slice(digits.length - places);

  return `${sign}${whole}.${fraction}`;
}
