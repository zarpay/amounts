import type { CompactOption, RoundingDirection } from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";
import { fillTemplate } from "@/helpers/template-helper.js";
import { Locale } from "@/models/locale.js";
import { Ratio } from "@/models/ratio.js";

/** Significant digits for `compact: true` (`Compact::DEFAULT_PRECISION`). */
const DEFAULT_PRECISION = 3;
/** How a short form joins its number, with no space: `"1.5M"`. */
const SHORT_FORMAT = "%n%u";

/** One scale: its power of ten, its I18n key and its short form. */
interface CompactScale {
  exponent: number;
  key: string;
  short: string;
}

/** Smallest first, as the gem's `Compact::SCALES`. */
const SCALES: readonly CompactScale[] = [
  { exponent: 3, key: "thousand", short: "K" },
  { exponent: 6, key: "million", short: "M" },
  { exponent: 9, key: "billion", short: "B" },
  { exponent: 12, key: "trillion", short: "T" },
  { exponent: 15, key: "quadrillion", short: "Qa" },
  { exponent: 18, key: "quintillion", short: "Qi" },
  { exponent: 21, key: "sextillion", short: "Sx" },
  { exponent: 24, key: "septillion", short: "Sp" },
  { exponent: 27, key: "octillion", short: "Oc" },
  { exponent: 30, key: "nonillion", short: "No" },
  { exponent: 33, key: "decillion", short: "Dc" },
];

const THOUSAND = Ratio.powerOfTen(3);

/**
 * Compact notation for large numbers — `ui({ compact: true })`, the gem's
 * `Amount::Compact`. For dashboards, charts and cards where `$1500000.00`
 * doesn't fit and `$1.5M` does.
 *
 * A number of at least one thousand is:
 *
 * 1. divided by the largest scale it reaches — thousand (`K`), million
 *    (`M`), billion (`B`), trillion (`T`), then `Qa`, `Qi`, `Sx`, `Sp`,
 *    `Oc`, `No` and decillion (`Dc`); past decillions it stays in them
 *    (`1500Dc`);
 * 2. rounded to `precision` significant digits (3 by default) in the
 *    display direction, so the default never rounds up: 1,999,999 is
 *    `1.99M`, never `2M`. When rounding up reaches the next scale, the
 *    next scale is used (999,999 ceils to `1M`, not `1000K`);
 * 3. trimmed of trailing zeros, and written in the locale's number format;
 * 4. joined with its scale word: the locale's translation (pluralized with
 *    the compacted number) through the locale's compact format, else the
 *    short form, joined directly (`"%n%u"`).
 *
 * Numbers below one thousand aren't compacted; {@link Display} formats
 * them as usual. The type's label and template still wrap the result, and
 * a plural label agrees with the full value, not the compacted digits.
 *
 * Internal: reach it through {@link Amount.ui}.
 *
 * @example
 *   amounts.of("USD", "1500000").ui({ compact: true });                   // "$1.5M"
 *   amounts.of("TOKENS", 1_234_567n).ui({ compact: { precision: 2 } });   // "1.2M TOKENS"
 *   amounts.of("TOKENS", 2_500_000n).ui({ compact: true, locale: "de" }); // "2,5 Millionen TOKENS"
 */
export class Compact {
  /**
   * Reads the `compact` option of `ui`.
   *
   * @param option - `true` (3 significant digits), `false`/`undefined`
   *   (off), or `{ precision }` with a positive integer
   * @returns the significant digits, or `null` when compact notation is off
   * @throws {@link AmountError} `INVALID_ARGUMENT` for anything else,
   *   including an unknown key or a precision below 1
   */
  static precision(option: CompactOption | null | undefined): number | null {
    if (option === undefined || option === null || option === false) return null;

    if (option === true) return DEFAULT_PRECISION;

    if (typeof option !== "object") throw errors.invalidCompactOption(option);

    return precisionFrom(option);
  }

  /**
   * Whether a number is large enough to compact: one thousand or more,
   * either sign.
   *
   * @param value - the whole-unit value, in the display unit if any
   */
  static applies(value: Ratio): boolean {
    const magnitude = value.abs();

    return magnitude.compare(THOUSAND) >= 0;
  }

  /**
   * The compacted number with its scale word, without the type's label.
   * Call only when {@link applies} is true.
   *
   * @param value - the whole-unit value, in the display unit if any
   * @param precision - significant digits, from {@link precision}
   * @param direction - the display rounding direction
   * @param locale - the locale's table, or `null` for the short forms
   * @returns `"1.5M"`, or `"1,5 Mio."` in a locale with translations
   */
  static format(
    value: Ratio,
    precision: number,
    direction: RoundingDirection,
    locale: Locale | null,
  ): string {
    let index = largestScale(value);

    for (;;) {
      const scale = SCALES[index]!;
      const { mantissa, decimals } = roundMantissa(value, scale.exponent, precision, direction);
      const magnitude = mantissa.abs();
      const reachedNext = magnitude.compare(THOUSAND) >= 0 && index < SCALES.length - 1;

      // Rounding up can reach the next scale: 999,999 ceils to 1000K, shown as 1M.
      if (reachedNext) {
        index += 1;
        continue;
      }

      const number = formatMantissa(mantissa, decimals, locale);

      return join(number, mantissa, scale, locale);
    }
  }
}

/** The precision in `{ precision }`, refusing unknown keys and non-positive digits. */
function precisionFrom(option: { precision?: unknown }): number {
  const unknown = Object.keys(option).filter((key) => key !== "precision");

  if (unknown.length > 0) {
    throw errors.invalidArgument(`unknown compact: option(s) ${unknown.join(", ")}`);
  }

  const digits = option.precision ?? DEFAULT_PRECISION;

  if (typeof digits !== "number" || !Number.isInteger(digits) || digits <= 0) {
    throw errors.invalidCompactPrecision(digits);
  }

  return digits;
}

/** The index in `SCALES` of the largest scale the value reaches. */
function largestScale(value: Ratio): number {
  const magnitude = value.abs();
  const reached = SCALES.filter((scale) => {
    const power = Ratio.powerOfTen(scale.exponent);

    return magnitude.compare(power) >= 0;
  });

  return reached.length - 1;
}

/** Divides by `10 ** exponent` and rounds to `precision` significant digits. */
function roundMantissa(
  value: Ratio,
  exponent: number,
  precision: number,
  direction: RoundingDirection,
): { mantissa: Ratio; decimals: number } {
  const power = Ratio.powerOfTen(exponent);
  const exact = value.divide(power);
  const magnitude = exact.abs();
  const whole = magnitude.truncate();
  const digits = Math.max(whole.toString().length, 1);
  const decimals = precision - digits;
  const mantissa = exact.round(decimals, direction);

  return { mantissa, decimals: Math.max(decimals, 0) };
}

/**
 * Writes a rounded mantissa with at most `decimals` places, trailing zeros
 * trimmed, in the locale's number format.
 */
function formatMantissa(mantissa: Ratio, decimals: number, locale: Locale | null): string {
  const exact = mantissa.toDecimal();
  const [whole = "", fraction = ""] = exact.split(".", 2);
  const kept = fraction.slice(0, decimals).replace(/0+$/, "");
  const plain = kept === "" ? whole : `${whole}.${kept}`;

  return locale === null ? plain : locale.applyNumber(plain);
}

/**
 * Joins the number and its scale word: the locale's word (pluralized with
 * the mantissa) through its compact format, else the short form.
 */
function join(number: string, mantissa: Ratio, scale: CompactScale, locale: Locale | null): string {
  const translation = locale?.compactUnit(scale.key) ?? null;
  const word = translation === null ? null : Locale.pluralize(translation, mantissa);

  if (locale === null || word === null || word === "") {
    return fillTemplate(SHORT_FORMAT, number, scale.short);
  }

  return fillTemplate(locale.compactFormat, number, word);
}
