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
 * Formats one amount for people, without changing its type — the gem's
 * `Amount::Display`, together with `Formattable#display_format`.
 *
 * Every {@link Amount} owns one and delegates `ui`, `unitLabel`,
 * `displayFormat`, `toString`, `formatted` and `inUnit` to it; call those
 * on the amount.
 *
 * ## How `ui` builds a string
 *
 * 1. **Value.** The exact whole-unit value, times the display unit's scale
 *    when a `unit` is given.
 * 2. **Round.** To the unit's `ui_decimals`, else the type's, in
 *    `direction` (`"floor"` by default, `"ceil"` to round up).
 * 3. **Write.** With exactly that many places; trailing zeros trimmed when
 *    `trimZeros` (the call's, else the unit's, else the type's) says so;
 *    then the locale's delimiter and separator. With `compact`, a number of
 *    one thousand or more is written in compact notation instead
 *    ({@link Compact}).
 * 4. **Decorate.** The label (translated in a locale, in the plural form
 *    that agrees with the rounded number) placed by the template: `%n` is
 *    the number and `%u` the label. Skipped when `decorated: false`, or when
 *    the type's label is empty.
 *
 * ## Where labels and templates come from
 *
 * First match wins. Without a locale, only the registered values are used.
 *
 * | | Display unit | Type |
 * | --- | --- | --- |
 * | Label | locale's unit label, unit's `symbol`, then the type's label | locale's type label, then `display_symbol` |
 * | Template | locale's unit format, unit's `format`/`position`, then the type's template | locale's type format, then `display_format` |
 *
 * Numbers are written from the exact value. The gem writes them through
 * `format("%.Nf")` — a `Float` — and prints wrong digits past about 15
 * significant figures; this writes the right ones.
 */
export class Display {
  private readonly amount: Amount;
  private readonly entry: RegistryEntry;

  /**
   * @param amount - the amount to format; it owns this display
   */
  constructor(amount: Amount) {
    this.amount = amount;
    this.entry = amount.registryEntry;
    Object.freeze(this);
  }

  /**
   * The amount for people. See the class description for each step.
   *
   * @param options - see {@link AmountUiOptions}
   * @returns the formatted string
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT` for a unit the type
   *   lacks, `UNKNOWN_LOCALE`, `INVALID_ARGUMENT` for a bad `compact` option
   *
   * @example
   *   amounts.of("USDC", "1.239").ui();                      // "$1.23"
   *   amounts.of("USDC", "1.231").ui({ direction: "ceil" }); // "$1.24"
   *   amounts.of("SOL", "2.5").ui();                         // "2.5 SOL" (trim_zeros: true)
   *   amounts.of("GOLD", "1").ui({ unit: "gram" });          // "31.10 g"
   *   amounts.of("EUR", "12.5").ui({ locale: "de" });        // "12,50 €"
   *   amounts.of("SEARCHES", 1n).ui();                       // "1 search"
   *   amounts.of("USD", "1500000").ui({ compact: true });    // "$1.5M"
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
   * The unit label alone, for a column header, a chip or an input
   * adornment. Resolved as `ui` resolves it (see the class description).
   * With `count`, a plural label takes the form that agrees with it;
   * without, the `other` form.
   *
   * @param options - `unit`, `locale`, and `count` (a `bigint`, `number` or
   *   decimal string)
   * @returns the label, or `""` for a type registered without one
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`, `UNKNOWN_LOCALE`,
   *   `INVALID_INPUT` for an unreadable count
   *
   * @example
   *   amounts.of("SEARCHES", 0n).unitLabel();               // "searches"
   *   amounts.of("SEARCHES", 0n).unitLabel({ count: 1 });   // "search"
   *   amounts.of("GOLD", "1").unitLabel({ locale: "de" });  // "Feinunze"
   */
  unitLabel(options: AmountUnitLabelOptions = {}): string {
    const locale = this.amount.amounts.localeFor(options.locale);
    const count = options.count === undefined ? null : readCount(options.count);
    const spec = options.unit === undefined ? null : this.entry.displayUnit(options.unit);

    return this.label(options.unit, spec, locale, count) ?? "";
  }

  /**
   * The template decorated `ui` output uses for the type, or for one of
   * its display units: the locale's, then the unit's own, then the type's.
   *
   * @param options - `unit` and `locale`
   * @returns a template containing `%n` (the number) and usually `%u` (the label)
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`, `UNKNOWN_LOCALE`
   *
   * @example
   *   amounts.of("USD", "1").displayFormat();                   // "%u%n"
   *   amounts.of("GOLD", "1").displayFormat({ unit: "grain" }); // "%u%n" (position: :prefix)
   */
  displayFormat(options: AmountDisplayFormatOptions = {}): string {
    const locale = this.amount.amounts.localeFor(options.locale);

    return this.formatIn(options.unit, locale);
  }

  /**
   * The gem's `to_s`: the symbol and the value rounded down to the type's
   * `ui_decimals`. Never localized, never trimmed, no label.
   *
   * @example
   *   amounts.of("USDC", "1.239").toString();  // "USDC|1.23"
   */
  toString(): string {
    const decimal = this.amount.toRatio();
    const rounded = decimal.round(this.entry.uiDecimals, "floor");
    const number = formatNumber(rounded, this.entry.uiDecimals, false, null);

    return `${this.entry.symbol}|${number}`;
  }

  /**
   * The exact value with exactly the type's storage `decimals` places —
   * the gem's `formatted`, and the number part of `toJSON`.
   *
   * @example
   *   amounts.of("USDC", "1.5").formatted();  // "1.500000"
   */
  formatted(): string {
    const decimal = this.amount.toRatio();

    return decimal.toFixed(this.entry.decimals);
  }

  /**
   * The exact value in a display unit, as the gem's `BigDecimal#to_s("F")`
   * writes it.
   *
   * @param unit - a display unit the type registered
   * @throws {@link AmountError} `INVALID_DISPLAY_UNIT`
   *
   * @example
   *   amounts.of("GOLD", "2").inUnit("kg");  // "0.0622069536"
   */
  inUnit(unit: string): string {
    const spec = this.entry.displayUnit(unit);
    const value = this.valueIn(spec);

    return value.toDecimal();
  }

  /** The whole-unit value, scaled into the display unit when there is one. */
  private valueIn(spec: DisplayUnit | null): Ratio {
    const decimal = this.amount.toRatio();

    if (spec === null) return decimal;

    // The manifest reader already proved the scale is a decimal.
    const scale = Ratio.parse(spec.scale)!;

    return decimal.multiply(scale);
  }

  /** Whether to trim trailing zeros: the call's choice, else the unit's, else the type's. */
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

  /** The template for the type or a unit, in an already-resolved locale. */
  private formatIn(unit: string | undefined, locale: Locale | null): string {
    if (unit === undefined) return this.typeFormat(locale);

    const spec = this.entry.displayUnit(unit);
    const localized = locale?.unitFormat(this.entry.symbol, unit) ?? null;

    return localized ?? spec.format ?? this.typeFormat(locale);
  }

  /** The label for the type or a unit, in the form that agrees with `count`. */
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

  /** The type's label: its translation in a locale, else `display_symbol`. */
  private typeLabel(locale: Locale | null, count: Ratio | null): string | null {
    if (locale === null) return Locale.plain(this.entry.displaySymbol, count);

    const translated = locale.typeLabel(this.entry.symbol);

    return Locale.pluralize(translated ?? this.entry.displaySymbol, count);
  }

  /** The type's template: the locale's, else the registered `display_format`. */
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

/** `"2.50"` → `"2.5"`, `"3.00"` → `"3"`: the gem's `trim_zeros`. */
function trimZeros(fixed: string): string {
  const stripped = fixed.replace(/(\.\d*?)0+$/, "$1");

  return stripped.endsWith(".") ? stripped.slice(0, -1) : stripped;
}

/** A `unitLabel` count, read exactly. */
function readCount(count: string | number | bigint): Ratio {
  const ratio = Ratio.parse(count);

  if (ratio === null) throw errors.cannotParse(count);

  return ratio;
}
