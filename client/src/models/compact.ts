import type { CompactOption, RoundingDirection } from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";
import { fillTemplate } from "@/helpers/template-helper.js";
import { Locale } from "@/models/locale.js";
import { Ratio } from "@/models/ratio.js";

const DEFAULT_PRECISION = 3;
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
 * Compact notation for large numbers, used by `ui({ compact })` — the
 * gem's `Amount::Compact`.
 *
 * A number of at least one thousand is divided by the largest scale it
 * reaches (up to decillions), rounded to a number of significant digits in
 * the given direction, trimmed of trailing zeros and joined with a scale
 * word: the locale's translation joined by its compact format, else the
 * short form (`K`, `M`, ...) joined as `"%n%u"`.
 */
export class Compact {
  /**
   * Reads the `compact` option: the significant digits, or `null` when
   * compact notation is off.
   *
   * @throws AmountError INVALID_ARGUMENT for anything but `true`, `false` or `{ precision }`
   */
  static precision(option: CompactOption | null | undefined): number | null {
    if (option === undefined || option === null || option === false) return null;

    if (option === true) return DEFAULT_PRECISION;

    if (typeof option !== "object") throw errors.invalidCompactOption(option);

    return precisionFrom(option);
  }

  /** Whether a number is large enough to compact. */
  static applies(value: Ratio): boolean {
    const magnitude = value.abs();

    return magnitude.compare(THOUSAND) >= 0;
  }

  /**
   * The compacted number with its scale word: `"1.5M"`, or `"1,5 Mio."`
   * in a locale. Call only when `applies` is true.
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
      const reachedNext = mantissa.abs().compare(THOUSAND) >= 0 && index < SCALES.length - 1;

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

function formatMantissa(mantissa: Ratio, decimals: number, locale: Locale | null): string {
  const exact = mantissa.toDecimal();
  const [whole = "", fraction = ""] = exact.split(".", 2);
  const kept = fraction.slice(0, decimals).replace(/0+$/, "");
  const plain = kept === "" ? whole : `${whole}.${kept}`;

  return locale === null ? plain : locale.applyNumber(plain);
}

function join(number: string, mantissa: Ratio, scale: CompactScale, locale: Locale | null): string {
  const translation = locale?.compactUnit(scale.key) ?? null;
  const word = translation === null ? null : Locale.pluralize(translation, mantissa);

  if (locale === null || word === null || word === "") {
    return fillTemplate(SHORT_FORMAT, number, scale.short);
  }

  return fillTemplate(locale.compactFormat, number, word);
}
