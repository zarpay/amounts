import type { Label } from "@/types.js";

import {
  readLabel,
  readNullable,
  readRecord,
  readString,
  readTemplate,
} from "@/helpers/manifest-helper.js";
import { Ratio } from "@/models/ratio.js";

/** A type's translations: its label and format, and each display unit's. */
interface LocaleTypeTable {
  label: Label | null;
  format: string | null;
  units: Map<string, { label: Label | null; format: string | null }>;
}

/**
 * One locale's table from the manifest, and the number and plural rules
 * the gem's `Amount::Locale` applies with it.
 *
 * The client never reads I18n files. When the server exports the manifest
 * with `Amount.manifest(locales: [...])`, the gem performs, for each
 * locale, every lookup the core would make — `number.format`, the type and
 * display-unit labels (`label_key` or `amounts.units.<sym>`), the
 * templates (`amounts.formats.<sym>`), the compact words
 * (`number.human.decimal_units`) — and writes the results here.
 *
 * Each reader returns the translation or `null`. The fallbacks — a missing
 * label to `display_symbol`, a missing template to the registered one —
 * stay with {@link Display} and {@link UiParser}, which apply them in the
 * gem's order, so they aren't written twice.
 *
 * Internal: {@link Amounts.localeFor} hands these to display and parsing.
 */
export class Locale {
  /** The locale's name, as exported (`"de"`). */
  readonly name: string;
  /** The thousands delimiter (`number.format.delimiter`, default `","`). */
  readonly delimiter: string;
  /** The decimal separator (`number.format.separator`, default `"."`). */
  readonly separator: string;
  /** The template joining a compacted number and its scale word (`"%n %u"`). */
  readonly compactFormat: string;

  private readonly compactUnits: Map<string, Label | null>;
  private readonly types: Map<string, LocaleTypeTable>;

  private constructor(
    name: string,
    number: { delimiter: string; separator: string },
    compactFormat: string,
    compactUnits: Map<string, Label | null>,
    types: Map<string, LocaleTypeTable>,
  ) {
    this.name = name;
    this.delimiter = number.delimiter;
    this.separator = number.separator;
    this.compactFormat = compactFormat;
    this.compactUnits = compactUnits;
    this.types = types;
    Object.freeze(this);
  }

  /**
   * Builds a locale from its manifest table, validating every field.
   * {@link Registry.fromManifest} calls this for each exported locale.
   *
   * @param name - the locale's name
   * @param value - its manifest table
   * @param path - where it was found, for error messages (`locales.de`)
   * @throws {@link AmountError} `INVALID_MANIFEST` naming the first malformed path
   */
  static fromManifest(name: string, value: unknown, path: string): Locale {
    const table = readRecord(value, path);
    const number = readRecord(table["number"], `${path}.number`);
    const compact = readRecord(table["compact"], `${path}.compact`);
    const delimiter = readString(number["delimiter"], `${path}.number.delimiter`);
    const separator = readString(number["separator"], `${path}.number.separator`);
    const compactFormat = readTemplate(compact["format"], `${path}.compact.format`);
    const compactUnits = readCompactUnits(compact["units"], `${path}.compact.units`);
    const types = readTypes(table["types"], `${path}.types`);

    return new Locale(name, { delimiter, separator }, compactFormat, compactUnits, types);
  }

  /**
   * Picks a label's form without a locale, as the gem's `Locale.plain`
   * does when it isn't localizing: `one` when the count is exactly 1 and
   * the form exists, else `other`. There is no `zero` form here — the gem
   * only uses it through I18n. A string passes through.
   *
   * @param label - a string, or plural forms
   * @param count - the number the label agrees with, or `null` for none
   * @returns the form, or `null` when there is no form to pick
   *
   * @example
   *   Locale.plain({ one: "search", other: "searches" }, Ratio.of(1n));  // "search"
   *   Locale.plain({ zero: "none", other: "searches" }, Ratio.of(0n));   // "searches"
   */
  static plain(label: Label, count: Ratio | null): string | null {
    if (typeof label === "string") return label;

    const isOne = count?.equals(ONE) ?? false;
    const one = label["one"];

    if (isOne && one !== undefined) return one;

    return label["other"] ?? null;
  }

  /**
   * Picks a label's form in a locale, by the I18n gem's default plural
   * rule: `zero` when the count is 0 and the form exists, `one` when it is
   * 1, else `other` — and `other` whenever the chosen form is missing (I18n
   * raises there, and the gem rescues to `other`) or there is no count.
   *
   * This is the rule an app gets without `rails-i18n`'s per-language
   * pluralization. Languages with more forms (`few`, `many`) fall back to
   * `other` for them, as they would on the server without those rules.
   *
   * @param label - a string, or plural forms
   * @param count - the number the label agrees with, or `null` for none
   * @returns the form, or `null` when there is no form to pick
   *
   * @example
   *   const forms = { zero: "keine Suchen", one: "Suche", other: "Suchen" };
   *   Locale.pluralize(forms, Ratio.of(0n));  // "keine Suchen"
   *   Locale.pluralize(forms, Ratio.of(1n));  // "Suche"
   *   Locale.pluralize(forms, null);          // "Suchen"
   */
  static pluralize(label: Label, count: Ratio | null): string | null {
    if (typeof label === "string") return label;

    if (count === null) return label["other"] ?? null;

    const key = pluralKey(label, count);

    return label[key] ?? label["other"] ?? null;
  }

  /**
   * The locale's word for a compact scale (`number.human.decimal_units.units.<scale>`),
   * raw — a string or plural forms — or `null` when it has none, in which
   * case compact notation falls back to the short form (`K`, `M`, ...).
   *
   * @param scale - `"thousand"`, `"million"`, ... `"decillion"`
   */
  compactUnit(scale: string): Label | null {
    return this.compactUnits.get(scale) ?? null;
  }

  /**
   * The locale's label for a type (its `label_key`, else
   * `amounts.units.<symbol downcased>`), raw, or `null` when untranslated.
   */
  typeLabel(symbol: string): Label | null {
    return this.types.get(symbol)?.label ?? null;
  }

  /**
   * The locale's template for a type (`amounts.formats.<symbol downcased>`),
   * or `null`. The gem drops a translation that doesn't place `%n`.
   */
  typeFormat(symbol: string): string | null {
    return this.types.get(symbol)?.format ?? null;
  }

  /**
   * The locale's label for a display unit (the unit's `label_key`, else
   * `amounts.display_units.<symbol downcased>.<unit>`), raw, or `null`.
   */
  unitLabel(symbol: string, unit: string): Label | null {
    return this.types.get(symbol)?.units.get(unit)?.label ?? null;
  }

  /**
   * The locale's template for a display unit
   * (`amounts.display_unit_formats.<symbol downcased>.<unit>`), or `null`.
   */
  unitFormat(symbol: string, unit: string): string | null {
    return this.types.get(symbol)?.units.get(unit)?.format ?? null;
  }

  /**
   * Rewrites a plain number with the locale's delimiter and separator,
   * grouping the whole part in threes — the gem's `Locale.apply`.
   *
   * @param plain - a number as `toFixed` writes it: an optional `-`,
   *   digits, and an optional `.` and fraction
   * @returns the number in the locale's format
   *
   * @example In German
   *   de.applyNumber("-1234567.50");  // "-1.234.567,50"
   */
  applyNumber(plain: string): string {
    const negative = plain.startsWith("-");
    const unsigned = negative ? plain.slice(1) : plain;
    const [whole = "", fraction] = unsigned.split(".", 2);
    const grouped = groupThousands(whole, this.delimiter);
    const sign = negative ? "-" : "";
    const decimals = fraction === undefined ? "" : `${this.separator}${fraction}`;

    return `${sign}${grouped}${decimals}`;
  }
}

const ONE = Ratio.of(1n);

/** I18n's default plural key for a count: `zero` (only when the form exists), `one` or `other`. */
function pluralKey(label: Readonly<Record<string, string>>, count: Ratio): string {
  if (count.isZero() && label["zero"] !== undefined) return "zero";

  return count.equals(ONE) ? "one" : "other";
}

function groupThousands(digits: string, delimiter: string): string {
  const groups: string[] = [];

  for (let end = digits.length; end > 0; end -= 3) {
    const start = Math.max(end - 3, 0);

    groups.unshift(digits.slice(start, end));
  }

  return groups.join(delimiter);
}

function readCompactUnits(value: unknown, path: string): Map<string, Label | null> {
  const units = readRecord(value, path);
  const entries = Object.entries(units).map(([scale, label]) => {
    const read = readNullable(label, `${path}.${scale}`, readLabel);

    return [scale, read] as const;
  });

  return new Map(entries);
}

function readTypes(value: unknown, path: string): Map<string, LocaleTypeTable> {
  const types = readRecord(value, path);
  const entries = Object.entries(types).map(([symbol, table]) => {
    const read = readType(table, `${path}.${symbol}`);

    return [symbol, read] as const;
  });

  return new Map(entries);
}

function readType(value: unknown, path: string): LocaleTypeTable {
  const table = readRecord(value, path);
  const label = readNullable(table["label"], `${path}.label`, readLabel);
  const format = readNullable(table["format"], `${path}.format`, readTemplate);
  const units = readUnits(table["units"], `${path}.units`);

  return { label, format, units };
}

function readUnits(
  value: unknown,
  path: string,
): Map<string, { label: Label | null; format: string | null }> {
  const units = readRecord(value, path);
  const entries = Object.entries(units).map(([unit, table]) => {
    const unitPath = `${path}.${unit}`;
    const unitTable = readRecord(table, unitPath);
    const label = readNullable(unitTable["label"], `${unitPath}.label`, readLabel);
    const format = readNullable(unitTable["format"], `${unitPath}.format`, readTemplate);

    return [unit, { label, format }] as const;
  });

  return new Map(entries);
}
