import type { Amount } from "@/models/amount.js";
import type { RegistryEntry } from "@/models/registry-entry.js";
import type {
  AmountDisplayFormatOptions,
  AmountUiOptions,
  AmountUnitLabelOptions,
  DisplayUnit,
} from "@/types.js";

import { errors } from "@/helpers/errors-helper.js";
import { fillTemplate } from "@/helpers/template-helper.js";
import { Compact } from "@/models/compact.js";
import { Locale } from "@/models/locale.js";
import { Ratio } from "@/models/ratio.js";

/**
 * Formats an amount for people without changing its type: the gem's
 * `Amount::Display`, with `Formattable#display_format` (which template
 * decorated output uses).
 *
 * Numbers are written from the exact value. Where the gem formats through
 * `format("%.Nf")` — a `Float` — and prints wrong digits past ~15
 * significant figures, this writes the right ones.
 */
export class Display {
  private readonly amount: Amount;
  private readonly entry: RegistryEntry;

  constructor(amount: Amount) {
    this.amount = amount;
    this.entry = amount.registryEntry;
    Object.freeze(this);
  }

  /**
   * The amount for people: rounded to the display decimals in `direction`,
   * in the locale's number format, with its label placed by the template.
   *
   * @throws AmountError INVALID_DISPLAY_UNIT, UNKNOWN_LOCALE, INVALID_ARGUMENT (compact)
   */
  ui(options: AmountUiOptions = {}): string {
    const direction = options.direction ?? "floor";
    const locale = this.amount.amounts.localeFor(options.locale);
    const precision = Compact.precision(options.compact);
    const spec = options.unit === undefined ? null : this.entry.displayUnit(options.unit);
    const value = this.valueIn(spec);
    const decimals = spec?.uiDecimals ?? this.entry.uiDecimals;
    const rounded = value.round(decimals, direction);
    const compacted = precision !== null && Compact.applies(value);
    const trim = this.resolveTrim(options.trimZeros, spec);
    const formatted = compacted
      ? Compact.format(value, precision, direction, locale)
      : formatNumber(rounded, decimals, trim, locale);

    if (options.decorated === false) return formatted;

    return this.decorate(formatted, rounded, options.unit, spec, locale);
  }

  /**
   * The unit label alone, for headers and chips: translated only in a
   * locale, else `display_symbol` (or the display unit's `symbol`). With
   * `count`, a plural label agrees with it; without, `other` is used.
   *
   * @throws AmountError INVALID_DISPLAY_UNIT, UNKNOWN_LOCALE, INVALID_INPUT (count)
   */
  unitLabel(options: AmountUnitLabelOptions = {}): string {
    const locale = this.amount.amounts.localeFor(options.locale);
    const count = options.count === undefined ? null : readCount(options.count);
    const spec = options.unit === undefined ? null : this.entry.displayUnit(options.unit);

    return this.label(options.unit, spec, locale, count) ?? "";
  }

  /**
   * The template decorated `ui` output uses for this type or one of its
   * display units. First match wins: the locale's template, then the
   * unit's own, then the type's.
   *
   * @throws AmountError INVALID_DISPLAY_UNIT, UNKNOWN_LOCALE
   */
  displayFormat(options: AmountDisplayFormatOptions = {}): string {
    const locale = this.amount.amounts.localeFor(options.locale);

    return this.formatIn(options.unit, locale);
  }

  /** `"USDC|1.50"`: the display-rounded compact string, never localized. */
  toString(): string {
    const decimal = this.amount.toRatio();
    const rounded = decimal.round(this.entry.uiDecimals, "floor");
    const number = formatNumber(rounded, this.entry.uiDecimals, false, null);

    return `${this.entry.symbol}|${number}`;
  }

  /** `"1.500000"`: the exact value with exactly `decimals` places. */
  formatted(): string {
    const decimal = this.amount.toRatio();

    return decimal.toFixed(this.entry.decimals);
  }

  /**
   * The value in a display unit, exactly: `"31.1034768"` grams for one
   * troy ounce.
   *
   * @throws AmountError INVALID_DISPLAY_UNIT
   */
  inUnit(unit: string): string {
    const spec = this.entry.displayUnit(unit);
    const value = this.valueIn(spec);

    return value.toDecimal();
  }

  private valueIn(spec: DisplayUnit | null): Ratio {
    const decimal = this.amount.toRatio();

    if (spec === null) return decimal;

    const scale = Ratio.parse(spec.scale)!;

    return decimal.multiply(scale);
  }

  private resolveTrim(callSite: boolean | null | undefined, spec: DisplayUnit | null): boolean {
    if (callSite !== undefined && callSite !== null) return callSite;

    if (spec?.trimZeros !== undefined && spec.trimZeros !== null) return spec.trimZeros;

    return this.entry.trimZeros;
  }

  /**
   * Places the number and its label with the display template. The label
   * agrees with `count`, the number as displayed; without a label there
   * is nothing to place, so the number is returned alone.
   */
  private decorate(
    number: string,
    count: Ratio,
    unit: string | undefined,
    spec: DisplayUnit | null,
    locale: Locale | null,
  ): string {
    const label = this.label(unit, spec, locale, count);

    if (label === null || label === "") return number;

    const template = this.formatIn(unit, locale);

    return fillTemplate(template, number, label);
  }

  private formatIn(unit: string | undefined, locale: Locale | null): string {
    if (unit === undefined) return this.typeFormat(locale);

    const spec = this.entry.displayUnit(unit);
    const localized = locale?.unitFormat(this.entry.symbol, unit) ?? null;

    return localized ?? spec.format ?? this.typeFormat(locale);
  }

  private label(
    unit: string | undefined,
    spec: DisplayUnit | null,
    locale: Locale | null,
    count: Ratio | null,
  ): string | null {
    if (spec === null || unit === undefined) return this.typeLabel(locale, count);

    const fallback = spec.symbol ?? this.entry.displaySymbol;

    if (locale === null) return Locale.plain(fallback, count);

    const translated = locale.unitLabel(this.entry.symbol, unit);
    const localized = translated ?? spec.symbol ?? this.typeLabel(locale, count);

    return localized === null ? null : Locale.pluralize(localized, count);
  }

  private typeLabel(locale: Locale | null, count: Ratio | null): string | null {
    if (locale === null) return Locale.plain(this.entry.displaySymbol, count);

    const translated = locale.typeLabel(this.entry.symbol);

    return Locale.pluralize(translated ?? this.entry.displaySymbol, count);
  }

  private typeFormat(locale: Locale | null): string {
    const localized = locale?.typeFormat(this.entry.symbol) ?? null;

    return localized ?? this.entry.displayFormat;
  }
}

/** Writes a rounded number with `decimals` places, trimmed and localized as asked. */
function formatNumber(
  value: Ratio,
  decimals: number,
  trim: boolean,
  locale: Locale | null,
): string {
  const fixed = value.toFixed(decimals);
  const trimmed = trim ? trimZeros(fixed) : fixed;

  return locale === null ? trimmed : locale.applyNumber(trimmed);
}

/** `"2.50"` → `"2.5"`, `"3.00"` → `"3"`. */
function trimZeros(fixed: string): string {
  const stripped = fixed.replace(/(\.\d*?)0+$/, "$1");

  return stripped.endsWith(".") ? stripped.slice(0, -1) : stripped;
}

function readCount(count: string | number | bigint): Ratio {
  const ratio = Ratio.parse(count);

  if (ratio === null) throw errors.cannotParse(count);

  return ratio;
}
